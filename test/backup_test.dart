import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shopping_list/apps/groceries/data/groceries_migrations.dart';
import 'package:shopping_list/apps/receipts/data/expense_repository.dart';
import 'package:shopping_list/apps/receipts/data/models/expense.dart';
import 'package:shopping_list/apps/receipts/data/receipts_migrations.dart';
import 'package:shopping_list/core/backup/app_backup.dart';
import 'package:shopping_list/core/db/database.dart';
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

  Future<AppDatabase> openLive() => AppDatabase.open(
        factory: databaseFactoryFfi,
        path: p.join(dir.path, 'live.db'),
        modules: [groceriesMigrations, receiptsMigrations],
      );

  test('zip holds the database, the photos and a counted manifest', () async {
    final database = await openLive();
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

    final inspected = AppBackup.inspect(zip.bytes);
    expect(inspected.imageCount, 1);
    expect(inspected.tables['expenses'], 1);
  });

  test('restore puts the expense and its photo back', () async {
    final database = await openLive();
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

    final restored = await openLive();
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

  test('a zip that is not a Spindle backup is refused', () {
    expect(
      () => AppBackup.inspect([1, 2, 3, 4, 5]),
      throwsA(isA<FormatException>()),
    );
  });
}
