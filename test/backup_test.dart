import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shopping_list/apps/groceries/data/groceries_migrations.dart';
import 'package:shopping_list/apps/groceries/data/shopping_repository.dart';
import 'package:shopping_list/apps/gym/data/gym_migrations.dart';
import 'package:shopping_list/apps/gym/data/gym_repository.dart';
import 'package:shopping_list/apps/receipts/data/expense_repository.dart';
import 'package:shopping_list/apps/receipts/data/models/expense.dart';
import 'package:shopping_list/apps/receipts/data/models/income.dart';
import 'package:shopping_list/apps/receipts/data/models/payment_method.dart';
import 'package:shopping_list/apps/receipts/data/models/recurring_rule.dart';
import 'package:shopping_list/apps/receipts/data/receipts_migrations.dart';
import 'package:shopping_list/core/backup/app_backup.dart';
import 'package:shopping_list/core/db/database.dart';
import 'package:shopping_list/core/db/migration.dart';
import 'package:shopping_list/core/db/migrator.dart';
import 'package:shopping_list/core/storage/image_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory dir;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('backup_test');
  });

  tearDown(() async {
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  /// The modules this worktree ships — what `main()` opens after restore.
  /// Last production commit (`8cdc896`) already had the same three apps.
  Future<AppDatabase> openCurrent({required String path}) => AppDatabase.open(
        factory: databaseFactoryFfi,
        path: path,
        modules: [groceriesMigrations, receiptsMigrations, gymMigrations],
      );

  /// A backup taken before gym shipped. Restore still has to keep the old
  /// rows and seed the gym tables on first open.
  Future<AppDatabase> openPreGym({required String path}) => AppDatabase.open(
        factory: databaseFactoryFfi,
        path: path,
        modules: [groceriesMigrations, receiptsMigrations],
      );

  test('zip holds the database, the photos and a counted manifest', () async {
    final database = await openCurrent(path: p.join(dir.path, 'live.db'));
    final images = ImageStore(root: Directory(p.join(dir.path, 'docs')));
    final repo = ExpenseRepository(database, images);

    final now = DateTime.now();
    final photo = File(p.join(dir.path, 'slip.jpg'))
      ..writeAsBytesSync([9, 8, 7]);
    await repo.create(
      draft: Expense(
        occurredAt: now,
        amountMinor: 4250,
        merchant: 'Rami Levy',
        receiptPath: '',
        createdAt: now,
        updatedAt: now,
      ),
      receiptSourcePath: photo.path,
    );

    final zip = await AppBackup(database, images).build();
    await database.close();

    expect(zip.fileName, startsWith('spindle_'));
    expect(zip.fileName, endsWith('.zip'));
    expect(zip.manifest.format, BackupManifest.currentFormat);
    expect(zip.manifest.imageCount, 1);
    expect(zip.manifest.tables['expenses'], 1);
    expect(zip.manifest.tables['activity'], 1);
    expect(zip.manifest.schemaVersions['receipts'],
        receiptsMigrations.latestVersion);
    expect(zip.manifest.schemaVersions['groceries'], 1);
    expect(zip.manifest.schemaVersions['gym'], gymMigrations.latestVersion);

    final inspected = AppBackup.inspect(zip.bytes);
    expect(inspected.imageCount, 1);
    expect(inspected.tables['expenses'], 1);
  });

  test('restore puts the expense and its photo back', () async {
    final database = await openCurrent(path: p.join(dir.path, 'live.db'));
    final docs = Directory(p.join(dir.path, 'docs'));
    final images = ImageStore(root: docs);
    final repo = ExpenseRepository(database, images);

    final now = DateTime.now();
    final photo = File(p.join(dir.path, 'slip.jpg'))
      ..writeAsBytesSync([1, 2, 3, 4]);
    final saved = await repo.create(
      draft: Expense(
        occurredAt: now,
        amountMinor: 9900,
        merchant: 'Super-Pharm',
        receiptPath: '',
        createdAt: now,
        updatedAt: now,
      ),
      receiptSourcePath: photo.path,
    );

    final zip = await AppBackup(database, images).build();

    await AppBackup.restore(
      zipBytes: zip.bytes,
      liveDbPath: database.path,
      documentsRoot: docs,
      closeLive: database.close,
    );

    final restored = await openCurrent(path: database.path);
    addTearDown(restored.close);
    final restoredRepo = ExpenseRepository(
      restored,
      ImageStore(root: docs),
    );
    final found = await restoredRepo.byId(saved.id!);
    expect(found, isNotNull);
    expect(found!.merchant, 'Super-Pharm');
    expect(found.amountMinor, 9900);
    expect(await restoredRepo.images.exists(found.receiptPath), isTrue);
  });

  test('a pre-gym backup reopens on this build with every old record intact',
      () async {
    final livePath = p.join(dir.path, 'live.db');
    final docs = Directory(p.join(dir.path, 'docs'));
    final database = await openPreGym(path: livePath);
    final images = ImageStore(root: docs);

    final shopping = ShoppingRepository(database, images);
    final milk = await shopping.addItem('Milk', quantity: 2);
    final bread = await shopping.addItem('Bread');
    await shopping.setPicked(milk.id!, picked: true);
    await shopping.setPicked(bread.id!, picked: true);
    await shopping.completeTrip(
      tripId: (await shopping.loadActiveList()).trip!.id!,
      totalMinor: 4250,
      note: 'Rami Levy',
    );
    await shopping.addItem('Eggs');

    final expenses = ExpenseRepository(database, images);
    final now = DateTime.now();
    final photo = File(p.join(dir.path, 'slip.jpg'))
      ..writeAsBytesSync([7, 7, 7]);
    final saved = await expenses.create(
      draft: Expense(
        occurredAt: now,
        amountMinor: 14250,
        merchant: 'Rami Levy',
        receiptPath: '',
        isBusiness: true,
        createdAt: now,
        updatedAt: now,
      ),
      receiptSourcePath: photo.path,
    );

    final zip = await AppBackup(database, images).build();
    expect(zip.manifest.tables['trips'], greaterThanOrEqualTo(1));
    expect(zip.manifest.tables['trip_items'], greaterThanOrEqualTo(1));
    expect(zip.manifest.tables['products'], greaterThanOrEqualTo(1));
    expect(zip.manifest.tables.containsKey('gym_sets'), isFalse);

    await AppBackup.restore(
      zipBytes: zip.bytes,
      liveDbPath: livePath,
      documentsRoot: docs,
      closeLive: database.close,
    );

    // This worktree's opener — gym is new relative to that backup.
    final restored = await openCurrent(path: livePath);
    addTearDown(restored.close);
    final restoredImages = ImageStore(root: docs);

    final list = await ShoppingRepository(restored, restoredImages)
        .loadActiveList();
    expect(list.items.single.nameSnapshot, 'Eggs');
    final history =
        await ShoppingRepository(restored, restoredImages).loadHistory();
    expect(history, hasLength(1));
    expect(history.single.trip.note, 'Rami Levy');
    expect(history.single.trip.totalMinor, 4250);
    final (_, tripItems) = (await ShoppingRepository(restored, restoredImages)
        .loadTrip(history.single.trip.id!))!;
    expect(tripItems.map((i) => i.nameSnapshot), containsAll(['Milk', 'Bread']));
    expect(tripItems.every((i) => i.isPicked), isTrue);

    final found = await ExpenseRepository(restored, restoredImages)
        .byId(saved.id!);
    expect(found, isNotNull);
    expect(found!.merchant, 'Rami Levy');
    expect(found.amountMinor, 14250);
    expect(found.isBusiness, isTrue);
    expect(await restoredImages.exists(found.receiptPath), isTrue);

    final versions = await Migrator.versions(restored.db);
    expect(versions['groceries'], groceriesMigrations.latestVersion);
    expect(versions['receipts'], receiptsMigrations.latestVersion);
    expect(versions['gym'], gymMigrations.latestVersion);

    final gym = GymRepository(restored);
    final rack = await gym.rack();
    expect(rack.map((e) => e.name), contains('Squat'));
    final squat = rack.firstWhere((e) => e.name == 'Squat');
    await gym.logSet(
      exerciseId: squat.id!,
      reps: 5,
      weightG: 80000,
      day: DateTime(2026, 8, 13),
    );
    expect(await gym.volumeOnDay(DateTime(2026, 8, 13)), 80000 * 5);
  });

  test('a current backup round-trips groceries, receipts and gym', () async {
    final livePath = p.join(dir.path, 'live.db');
    final docs = Directory(p.join(dir.path, 'docs'));
    final database = await openCurrent(path: livePath);
    final images = ImageStore(root: docs);

    final shopping = ShoppingRepository(database, images);
    await shopping.addItem('Oat milk');

    final expenses = ExpenseRepository(database, images);
    final now = DateTime.now();
    final photo = File(p.join(dir.path, 'gym-slip.jpg'))
      ..writeAsBytesSync([3, 2, 1]);
    await expenses.create(
      draft: Expense(
        occurredAt: now,
        amountMinor: 2500,
        merchant: 'Cafe',
        receiptPath: '',
        createdAt: now,
        updatedAt: now,
      ),
      receiptSourcePath: photo.path,
    );

    final gym = GymRepository(database);
    final bench = (await gym.exercises())
        .firstWhere((e) => e.name == 'Bench press');
    await gym.logSet(
      exerciseId: bench.id!,
      reps: 8,
      weightG: 60000,
      day: DateTime(2026, 8, 18),
    );

    final zip = await AppBackup(database, images).build();
    expect(zip.manifest.tables['gym_sets'], 1);
    expect(zip.manifest.tables['trip_items'], 1);
    expect(zip.manifest.tables['activity'], greaterThanOrEqualTo(1));
    expect(zip.manifest.schemaVersions['gym'], gymMigrations.latestVersion);
    expect(zip.manifest.schemaVersions['receipts'],
        receiptsMigrations.latestVersion);

    await AppBackup.restore(
      zipBytes: zip.bytes,
      liveDbPath: livePath,
      documentsRoot: docs,
      closeLive: database.close,
    );

    final restored = await openCurrent(path: livePath);
    addTearDown(restored.close);
    final restoredImages = ImageStore(root: docs);

    expect(
      (await ShoppingRepository(restored, restoredImages).loadActiveList())
          .items
          .single
          .nameSnapshot,
      'Oat milk',
    );
    expect(
      (await ExpenseRepository(restored, restoredImages).recent())
          .single
          .merchant,
      'Cafe',
    );
    expect(
      await GymRepository(restored).volumeOnDay(DateTime(2026, 8, 18)),
      60000 * 8,
    );
    final cafe = (await ExpenseRepository(restored, restoredImages).recent())
        .single;
    expect(await restoredImages.exists(cafe.receiptPath), isTrue);

    final versions = await Migrator.versions(restored.db);
    expect(versions['groceries'], groceriesMigrations.latestVersion);
    expect(versions['receipts'], receiptsMigrations.latestVersion);
    expect(versions['gym'], gymMigrations.latestVersion);
    expect(versions['core'], 1);
  });

  test('a current backup round-trips the whole financial manager', () async {
    final livePath = p.join(dir.path, 'live.db');
    final docs = Directory(p.join(dir.path, 'docs'));
    final database = await openCurrent(path: livePath);
    final images = ImageStore(root: docs);
    final repo = ExpenseRepository(database, images);

    final account = await repo.addAccount('Bank Leumi', kind: 'bank');
    await repo.setOpeningBalance(account.id!, 1000000);

    final card = await repo.addPaymentMethod(
      PaymentMethod(
        accountId: account.id!,
        name: 'Visa gold',
        settlement: Settlement.indirect,
        statementDay: 10,
        creditLimitMinor: 1000000,
        last4: '4471',
        createdAt: DateTime(2026, 1, 1),
      ),
    );
    // The direct method created alongside the account itself.
    final transfer = (await repo.paymentMethods()).firstWhere(
      (m) => m.accountId == account.id && m.settlement == Settlement.direct,
    );

    final photo = File(p.join(dir.path, 'slip.jpg'))
      ..writeAsBytesSync([4, 5, 6]);
    final now = DateTime(2026, 8, 12);
    await repo.create(
      draft: Expense(
        occurredAt: now,
        amountMinor: 31300,
        merchant: 'Sony',
        paymentMethodId: card.id,
        installments: 3,
        interestBp: 600,
        receiptPath: '',
        createdAt: now,
        updatedAt: now,
      ),
      receiptSourcePath: photo.path,
    );
    await repo.createWithoutReceipt(
      Expense(
        occurredAt: now,
        amountMinor: 41200,
        merchant: 'Electricity',
        paymentMethodId: transfer.id,
        receiptPath: '',
        createdAt: now,
        updatedAt: now,
      ),
    );

    await repo.addIncome(
      Income(
        occurredAt: DateTime(2026, 8, 10),
        amountMinor: 2130000,
        sourceName: 'Salary',
        accountId: account.id,
        createdAt: now,
      ),
    );

    await repo.addRecurringRule(
      RecurringRule(
        name: 'Rent',
        amountMinor: 320000,
        paymentMethodId: transfer.id,
        dayOfMonth: 1,
        startsOn: DateTime(2026, 1, 1),
        createdAt: now,
      ),
    );

    final zip = await AppBackup(database, images).build();
    // Three seeded accounts each got a direct method in the migration, plus
    // Bank Leumi's own and the card.
    expect(zip.manifest.tables['payment_methods'], 5);
    expect(zip.manifest.tables['incomes'], 1);
    expect(zip.manifest.tables['recurring_rules'], 1);
    // The direct expense and the salary. A credit charge is deliberately not a
    // ledger entry until the statement settles.
    expect(zip.manifest.tables['account_entries'], 2);

    await AppBackup.restore(
      zipBytes: zip.bytes,
      liveDbPath: livePath,
      documentsRoot: docs,
      closeLive: database.close,
    );

    final restored = await openCurrent(path: livePath);
    addTearDown(restored.close);
    final restoredRepo = ExpenseRepository(restored, ImageStore(root: docs));

    final methods = await restoredRepo.paymentMethods();
    final visa = methods.firstWhere((m) => m.name == 'Visa gold');
    expect(visa.settlement, Settlement.indirect);
    expect(visa.statementDay, 10);
    expect(visa.creditLimitMinor, 1000000);
    expect(visa.label, 'Visa gold ·4471');

    final split = (await restoredRepo.recent())
        .firstWhere((e) => e.merchant == 'Sony');
    expect(split.installments, 3);
    expect(split.interestBp, 600);
    expect(split.isSplit, isTrue);

    final auto = (await restoredRepo.recent())
        .firstWhere((e) => e.merchant == 'Electricity');
    expect(auto.hasReceipt, isFalse);
    expect(auto.accountId, account.id);

    // Opening + salary − the direct expense. The card charge is still on the
    // card, so it must not have moved the balance.
    final standing = (await restoredRepo.standings(now: DateTime(2026, 8, 12)))
        .firstWhere((s) => s.account.id == account.id);
    expect(standing.balanceMinor, 1000000 + 2130000 - 41200);
    expect(standing.committed[visa.id], 31300);
    expect(standing.owedMinor, 31300);

    expect((await restoredRepo.recentIncomes()).single.sourceName, 'Salary');
    expect((await restoredRepo.recurringRules()).single.name, 'Rent');
    expect((await restoredRepo.ledgerFor(account.id!)), hasLength(2));
  });

  test('the v3 migration gives every old account a way to pay from it',
      () async {
    final path = p.join(dir.path, 'live.db');
    final when = DateTime(2026, 7, 4);

    // A database as it stood before payment methods existed.
    final old = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: path,
      modules: [
        ModuleMigrations(
          moduleId: receiptsMigrations.moduleId,
          migrations: [
            for (final m in receiptsMigrations.migrations)
              if (m.version <= 2) m,
          ],
        ),
      ],
    );
    final accountId = await old.db.insert('accounts', {
      'name': 'Bank Leumi',
      'kind': 'bank',
      'last4': '8812',
      'sort': 0,
    });
    await old.db.insert('expenses', {
      'occurred_at': when.millisecondsSinceEpoch,
      'amount_minor': 28490,
      'currency': 'ILS',
      'merchant': 'Rami Levy',
      'account_id': accountId,
      'receipt_path': 'receipts/old.jpg',
      'source': 'manual',
      'is_business': 0,
      'created_at': when.millisecondsSinceEpoch,
      'updated_at': when.millisecondsSinceEpoch,
    });
    await old.close();

    final upgraded = await openCurrent(path: path);
    addTearDown(upgraded.close);
    final repo = ExpenseRepository(
      upgraded,
      ImageStore(root: Directory(p.join(dir.path, 'docs'))),
    );

    final method = (await repo.paymentMethods())
        .singleWhere((m) => m.accountId == accountId);
    expect(method.settlement, Settlement.direct);
    expect(method.label, 'Bank Leumi ·8812');

    // The existing slip keeps its "paid with" rather than going blank.
    final expense = (await repo.recent()).single;
    expect(expense.paymentMethodId, method.id);
    expect(expense.installments, 1);
    expect(expense.interestBp, 0);

    // And it is already in the ledger, so a balance means something the first
    // time Accounts is opened.
    final lines = await repo.ledgerFor(accountId);
    expect(lines, hasLength(1));
    expect(lines.single.entry.amountMinor, -28490);
    expect(lines.single.balanceAfter, -28490);
  });

  test('the production capture from before payment methods loads in this build',
      () async {
    // The zip exported on 18 Aug 2026, receipts schema 2 — the last dump
    // taken before the financial manager landed. Restore has to keep every
    // slip, trip, gym set and photo, and the v3 backfill has to give each
    // old account a payment method without inventing or dropping money.
    final zipFile = File(
      p.join('test', 'fixtures', 'spindle_2026-08-18_0257.zip'),
    );
    expect(
      zipFile.existsSync(),
      isTrue,
      reason: 'Place spindle_2026-08-18_0257.zip in test/fixtures.',
    );

    final livePath = p.join(dir.path, 'shopping_list.db');
    final docs = Directory(p.join(dir.path, 'docs'))..createSync();
    final bytes = await zipFile.readAsBytes();

    final inspected = AppBackup.inspect(bytes);
    expect(inspected.format, BackupManifest.currentFormat);
    expect(inspected.schemaVersions['receipts'], 2);
    expect(inspected.tables['expenses'], 12);
    expect(inspected.tables['accounts'], 3);
    expect(inspected.tables.containsKey('payment_methods'), isFalse);
    expect(inspected.imageCount, 12);

    await AppBackup.restore(
      zipBytes: bytes,
      liveDbPath: livePath,
      documentsRoot: docs,
    );

    final restored = await openCurrent(path: livePath);
    addTearDown(restored.close);
    final images = ImageStore(root: docs);
    final expenses = ExpenseRepository(restored, images);
    final groceries = ShoppingRepository(restored, images);
    final gym = GymRepository(restored);

    final versions = await Migrator.versions(restored.db);
    expect(versions['receipts'], 3);
    expect(versions['groceries'], 1);
    expect(versions['gym'], 1);

    final slips = await expenses.recent();
    expect(slips, hasLength(12));
    expect(
      slips.map((e) => e.merchant).toSet(),
      containsAll(<String>[
        'אושר עד',
        'אביב בעיר נסטי',
        'בורקס ואייס קפה לפני אימון',
        'הדפסה לשעיה',
        'TAQUERIA DELIVERY',
        'המקום של ניר בע"מ',
      ]),
    );
    expect(
      slips.fold<int>(0, (sum, e) => sum + e.amountMinor),
      44207,
    );

    final accounts = await expenses.accounts();
    expect(accounts.map((a) => a.name).toList(),
        ['Cash', 'Credit card', 'Debit card']);

    final methods = await expenses.paymentMethods();
    expect(methods, hasLength(3));
    expect(methods.every((m) => m.settlement == Settlement.direct), isTrue);
    expect(
      methods.map((m) => m.accountId).toSet(),
      accounts.map((a) => a.id).toSet(),
    );

    final byAccount = {for (final m in methods) m.accountId: m};
    for (final slip in slips) {
      expect(slip.installments, 1);
      expect(slip.interestBp, 0);
      if (slip.accountId == null) {
        expect(slip.paymentMethodId, isNull);
      } else {
        expect(slip.paymentMethodId, byAccount[slip.accountId]!.id);
      }
      expect(await images.exists(slip.receiptPath), isTrue,
          reason: '${slip.merchant} lost ${slip.receiptPath}');
    }

    // Eight of the twelve slips named an account. Those eight must already
    // be in the passbook so Accounts is not empty the first time it opens.
    var ledgerRows = 0;
    for (final account in accounts) {
      ledgerRows += (await expenses.ledgerFor(account.id!)).length;
    }
    expect(ledgerRows, 8);

    final credit = accounts.singleWhere((a) => a.name == 'Credit card');
    final creditLines = await expenses.ledgerFor(credit.id!);
    expect(
      creditLines.fold<int>(0, (sum, l) => sum - l.entry.amountMinor),
      slips
          .where((e) => e.accountId == credit.id)
          .fold<int>(0, (sum, e) => sum + e.amountMinor),
    );

    expect((await groceries.loadHistory()), hasLength(3));
    expect((await groceries.loadActiveList()).items, isEmpty);
    expect(await gym.volumeOnDay(DateTime(2026, 8, 17)), greaterThan(0));
  });

  test('a zip that is not a Spindle backup is refused', () {
    expect(
      () => AppBackup.inspect([1, 2, 3, 4, 5]),
      throwsA(isA<FormatException>()),
    );
  });
}
