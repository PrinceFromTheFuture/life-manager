import 'package:shopping_list/core/db/migration.dart';

/// Schema owned by the groceries app.
///
/// **Adoption matters here.** These exact tables already exist on the device,
/// created by sqflite's `onCreate` before the per-module migrator existed, and
/// they hold real shopping history. `adoptIfTableExists: 'trips'` tells the
/// migrator to record this module at version 1 and skip migration 1 entirely
/// when it finds those tables — rather than running `CREATE TABLE` over live
/// data.
///
/// Every statement below is also `IF NOT EXISTS`, so even if adoption were
/// somehow missed the migration would be inert rather than destructive. Belt
/// and braces, because the failure mode is losing someone's history.
const ModuleMigrations groceriesMigrations = ModuleMigrations(
  moduleId: 'groceries',
  adoptIfTableExists: 'trips',
  adoptAtVersion: 1,
  migrations: [
    Migration(
      version: 1,
      statements: [
        '''
        CREATE TABLE IF NOT EXISTS products (
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
        CREATE TABLE IF NOT EXISTS trips (
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
        CREATE TABLE IF NOT EXISTS trip_items (
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

        // At most one active trip, enforced by the database rather than
        // trusted to application code.
        '''
        CREATE UNIQUE INDEX IF NOT EXISTS idx_single_active_trip
          ON trips(status) WHERE status = 'active'
        ''',
        '''
        CREATE INDEX IF NOT EXISTS idx_products_ranking
          ON products(usage_count DESC, last_used_at DESC)
        ''',
        '''
        CREATE INDEX IF NOT EXISTS idx_trip_items_trip
          ON trip_items(trip_id, sort_order)
        ''',
        '''
        CREATE INDEX IF NOT EXISTS idx_trips_history
          ON trips(status, completed_at DESC)
        ''',
      ],
    ),
  ],
);
