import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shopping_list/apps/groceries/data/groceries_migrations.dart';
import 'package:shopping_list/core/db/database.dart';
import 'package:shopping_list/core/db/migration.dart';
import 'package:shopping_list/core/db/migrator.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The exact statements the app shipped with *before* the per-module migrator
/// existed — no `IF NOT EXISTS`, created through sqflite's own `onCreate`.
///
/// Reproduced verbatim rather than reusing `groceriesMigrations` because the
/// whole point is to recreate the shape of the database sitting on a real
/// phone. A test built from the current schema would prove nothing.
const List<String> _legacyV1 = [
  '''
  CREATE TABLE products (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    name            TEXT    NOT NULL,
    name_normalized TEXT    NOT NULL UNIQUE,
    default_unit    TEXT,
    usage_count     INTEGER NOT NULL DEFAULT 0,
    last_used_at    INTEGER,
    created_at      INTEGER NOT NULL
  )
  ''',
  '''
  CREATE TABLE trips (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    status       TEXT    NOT NULL CHECK (status IN ('active', 'completed')),
    started_at   INTEGER NOT NULL,
    completed_at INTEGER,
    total_minor  INTEGER,
    currency     TEXT    NOT NULL DEFAULT 'ILS',
    receipt_path TEXT,
    note         TEXT
  )
  ''',
  '''
  CREATE TABLE trip_items (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    trip_id       INTEGER NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
    product_id    INTEGER REFERENCES products(id) ON DELETE SET NULL,
    name_snapshot TEXT    NOT NULL,
    quantity      REAL    NOT NULL DEFAULT 1,
    unit          TEXT,
    is_picked     INTEGER NOT NULL DEFAULT 0,
    picked_at     INTEGER,
    sort_order    INTEGER NOT NULL DEFAULT 0,
    price_minor   INTEGER
  )
  ''',
  '''
  CREATE UNIQUE INDEX idx_single_active_trip
    ON trips(status) WHERE status = 'active'
  ''',
];

void main() {
  late Directory dir;
  late String dbPath;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('migrator_test');
    dbPath = p.join(dir.path, 'test.db');
  });

  tearDown(() async {
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  group('adopting a database that predates the migrator', () {
    test('keeps existing data and does not recreate its tables', () async {
      // Build the legacy database and put real data in it.
      final legacy = await databaseFactoryFfi.openDatabase(dbPath);
      for (final statement in _legacyV1) {
        await legacy.execute(statement);
      }
      await legacy.insert('trips', {
        'status': 'completed',
        'started_at': 1000,
        'completed_at': 2000,
        'total_minor': 14250,
        'currency': 'ILS',
      });
      await legacy.insert('products', {
        'name': 'Milk',
        'name_normalized': 'milk',
        'usage_count': 3,
        'created_at': 1000,
      });
      await legacy.close();

      // Now open it the way the shipping app does.
      final db = await AppDatabase.open(
        factory: databaseFactoryFfi,
        path: dbPath,
        modules: [groceriesMigrations],
      );

      // The data is the thing. If adoption failed, the CREATE TABLE would have
      // thrown or, worse, silently replaced it.
      final trips = await db.db.query('trips');
      expect(trips, hasLength(1));
      expect(trips.single['total_minor'], 14250);

      final products = await db.db.query('products');
      expect(products.single['name'], 'Milk');
      expect(products.single['usage_count'], 3);

      final versions = await Migrator.versions(db.db);
      expect(versions['groceries'], 1, reason: 'adopted at its baseline');
      expect(versions['core'], 1, reason: 'core genuinely ran');

      await db.close();
    });

    test('still creates the activity table, which the legacy db lacks',
        () async {
      final legacy = await databaseFactoryFfi.openDatabase(dbPath);
      for (final statement in _legacyV1) {
        await legacy.execute(statement);
      }
      await legacy.close();

      final db = await AppDatabase.open(
        factory: databaseFactoryFfi,
        path: dbPath,
        modules: [groceriesMigrations],
      );

      // Core has no adoption clause precisely so that this runs.
      await db.db.insert('activity', {
        'app_id': 'groceries',
        'kind': 'trip_completed',
        'title': 'Shopping trip',
        'occurred_at': 5000,
      });
      expect(await db.db.query('activity'), hasLength(1));

      await db.close();
    });
  });

  group('a fresh database', () {
    test('creates every module schema from nothing', () async {
      final db = await AppDatabase.open(
        factory: databaseFactoryFfi,
        path: dbPath,
        modules: [groceriesMigrations],
      );

      for (final table in ['products', 'trips', 'trip_items', 'activity']) {
        final rows = await db.db.rawQuery(
          "SELECT 1 FROM sqlite_master WHERE type='table' AND name=?",
          [table],
        );
        expect(rows, isNotEmpty, reason: '$table should exist');
      }

      await db.close();
    });
  });

  group('repeated opens', () {
    test('are inert — migrations do not run twice', () async {
      var db = await AppDatabase.open(
        factory: databaseFactoryFfi,
        path: dbPath,
        modules: [groceriesMigrations],
      );
      await db.db.insert('products', {
        'name': 'Bread',
        'name_normalized': 'bread',
        'usage_count': 0,
        'created_at': 1,
      });
      await db.close();

      // Every launch of the app re-runs the migrator; it must be a no-op.
      db = await AppDatabase.open(
        factory: databaseFactoryFfi,
        path: dbPath,
        modules: [groceriesMigrations],
      );
      expect(await db.db.query('products'), hasLength(1));
      expect((await Migrator.versions(db.db))['groceries'], 1);
      await db.close();
    });
  });

  group('modules version independently', () {
    test('a new module migrates without touching an existing one', () async {
      var db = await AppDatabase.open(
        factory: databaseFactoryFfi,
        path: dbPath,
        modules: [groceriesMigrations],
      );
      await db.close();

      // Simulates installing a second mini-app in a later build.
      const newcomer = ModuleMigrations(
        moduleId: 'receipts',
        migrations: [
          Migration(
            version: 1,
            statements: ['CREATE TABLE expenses (id INTEGER PRIMARY KEY)'],
          ),
        ],
      );

      db = await AppDatabase.open(
        factory: databaseFactoryFfi,
        path: dbPath,
        modules: [groceriesMigrations, newcomer],
      );

      final versions = await Migrator.versions(db.db);
      expect(versions['groceries'], 1);
      expect(versions['receipts'], 1);
      expect(
        await db.db.rawQuery(
          "SELECT 1 FROM sqlite_master WHERE type='table' AND name='expenses'",
        ),
        isNotEmpty,
      );

      await db.close();
    });
  });
}
