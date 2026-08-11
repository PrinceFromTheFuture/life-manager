import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/apps/receipts/data/expense_repository.dart';
import 'package:shopping_list/apps/receipts/data/models/expense.dart';
import 'package:shopping_list/apps/receipts/data/receipts_activity.dart';
import 'package:shopping_list/apps/receipts/data/receipts_migrations.dart';
import 'package:shopping_list/core/activity/activity_dao.dart';
import 'package:shopping_list/core/db/database.dart';
import 'package:shopping_list/core/storage/image_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late AppDatabase database;
  late ExpenseRepository repo;
  late Directory tempDir;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    database = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
      modules: [receiptsMigrations],
    );
    tempDir = await Directory.systemTemp.createTemp('expense_test');
    repo = ExpenseRepository(database, ImageStore(root: tempDir));
  });

  tearDown(() async {
    await database.close();
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  /// A stand-in for a photographed receipt.
  File receiptFile([String name = 'receipt.jpg']) =>
      File('${tempDir.path}/$name')..writeAsBytesSync([1, 2, 3]);

  Expense draft({
    int amount = 14250,
    String? merchant = 'Rami Levy',
    int? categoryId,
    String? location,
  }) {
    final now = DateTime.now();
    return Expense(
      occurredAt: now,
      amountMinor: amount,
      merchant: merchant,
      categoryId: categoryId,
      locationLabel: location,
      receiptPath: '',
      createdAt: now,
      updatedAt: now,
    );
  }

  group('seeds', () {
    test('categories and accounts are ready to use out of the box', () async {
      final categories = await repo.categories();
      final accounts = await repo.accounts();

      // Being made to define "Groceries" before logging your first expense
      // would be a poor first run.
      expect(categories, isNotEmpty);
      expect(categories.map((c) => c.name), contains('Groceries'));
      expect(accounts.map((a) => a.name), contains('Cash'));
    });

    test('re-running the migration does not duplicate them', () async {
      final before = (await repo.categories()).length;
      // `INSERT OR IGNORE` means a second run is inert.
      for (final statement in receiptsMigrations.migrations.first.statements) {
        await database.db.execute(statement);
      }
      expect((await repo.categories()).length, before);
    });
  });

  group('creating an expense', () {
    test('stores a relative receipt path that resolves back', () async {
      final saved = await repo.create(
        draft: draft(),
        receiptSourcePath: receiptFile().path,
      );

      expect(saved.receiptPath.startsWith('receipts/'), isTrue);
      expect(saved.receiptPath.contains(tempDir.path), isFalse);
      expect(await repo.images.exists(saved.receiptPath), isTrue);
    });

    test('writes exactly one matching feed entry', () async {
      final saved = await repo.create(
        draft: draft(location: 'Ibn Gabirol 30'),
        receiptSourcePath: receiptFile().path,
      );

      final entries = await ActivityDao(database.db).recent();
      expect(entries, hasLength(1));
      expect(entries.single.appId, ReceiptActivity.appId);
      expect(entries.single.amountMinor, 14250);
      expect(entries.single.title, 'Rami Levy');
      expect(entries.single.subtitle, 'Ibn Gabirol 30');
      expect(entries.single.refId, saved.id);
    });

    test('a receipt is mandatory at the database level', () async {
      // Not merely a form rule — no code path may create an expense without
      // one, so this asserts against the column directly.
      expect(
        () => database.db.insert('expenses', {
          'occurred_at': 1,
          'amount_minor': 100,
          'currency': 'ILS',
          'source': 'manual',
          'created_at': 1,
          'updated_at': 1,
        }),
        throwsA(isA<DatabaseException>()),
      );
    });
  });

  group('merchant learns its category', () {
    test('predicts the category used most often for that shop', () async {
      final categories = await repo.categories();
      final groceries = categories.firstWhere((c) => c.name == 'Groceries');
      final fuel = categories.firstWhere((c) => c.name == 'Fuel');

      expect(await repo.predictCategory('Rami Levy'), isNull);

      await repo.create(
        draft: draft(categoryId: groceries.id),
        receiptSourcePath: receiptFile('a.jpg').path,
      );
      await repo.create(
        draft: draft(categoryId: groceries.id),
        receiptSourcePath: receiptFile('b.jpg').path,
      );
      await repo.create(
        draft: draft(categoryId: fuel.id),
        receiptSourcePath: receiptFile('c.jpg').path,
      );

      // Two groceries against one fuel — the form should preselect groceries.
      expect(await repo.predictCategory('Rami Levy'), groceries.id);
    });

    test('matching ignores case and spacing', () async {
      final groceries =
          (await repo.categories()).firstWhere((c) => c.name == 'Groceries');
      await repo.create(
        draft: draft(merchant: 'Rami Levy', categoryId: groceries.id),
        receiptSourcePath: receiptFile().path,
      );

      expect(await repo.predictCategory('  rami   levy '), groceries.id);
    });
  });

  group('editing', () {
    test('corrects the cached feed entry rather than leaving it stale',
        () async {
      final saved = await repo.create(
        draft: draft(amount: 10000, merchant: 'Wrong shop'),
        receiptSourcePath: receiptFile().path,
      );

      await repo.update(
        saved.copyWith(amountMinor: 25000, merchant: 'Right shop'),
      );

      final entries = await ActivityDao(database.db).recent();
      expect(entries, hasLength(1), reason: 'no duplicate entry');
      expect(entries.single.amountMinor, 25000);
      expect(entries.single.title, 'Right shop');
    });
  });

  group('deleting', () {
    test('removes the expense, its feed entry and its image', () async {
      final saved = await repo.create(
        draft: draft(),
        receiptSourcePath: receiptFile().path,
      );

      await repo.delete(saved.id!);

      expect(await repo.recent(), isEmpty);
      expect(await ActivityDao(database.db).recent(), isEmpty);
      expect(await repo.images.exists(saved.receiptPath), isFalse);
    });
  });

  group('month to date', () {
    test('sums only expenses inside the window', () async {
      final now = DateTime.now();
      final thisMonth = DateTime(now.year, now.month, 15);
      final lastMonth = DateTime(now.year, now.month - 1, 15);

      await repo.create(
        draft: draft(amount: 5000).copyWith(occurredAt: thisMonth),
        receiptSourcePath: receiptFile('a.jpg').path,
      );
      await repo.create(
        draft: draft(amount: 9900).copyWith(occurredAt: lastMonth),
        receiptSourcePath: receiptFile('b.jpg').path,
      );

      final total = await repo.totalBetween(
        DateTime(now.year, now.month),
        DateTime(now.year, now.month + 1),
      );
      expect(total, 5000);
    });
  });
}
