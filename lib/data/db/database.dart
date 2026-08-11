import 'package:sqflite/sqflite.dart';

/// Opens and migrates the SQLite database.
///
/// The factory is injectable so the entire data layer can be exercised
/// headlessly in tests against `sqflite_common_ffi` in-memory, with no emulator
/// and no device.
class AppDatabase {
  AppDatabase._(this.db);

  final Database db;

  static const int schemaVersion = 1;
  static const String fileName = 'shopping_list.db';

  static Future<AppDatabase> open({
    DatabaseFactory? factory,
    String? path,
  }) async {
    final f = factory ?? databaseFactory;
    final dbPath = path ?? '${await f.getDatabasesPath()}/$fileName';

    final db = await f.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onConfigure: _onConfigure,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );
    return AppDatabase._(db);
  }

  /// Foreign keys are off by default in SQLite and must be enabled per
  /// connection, before any migration runs.
  static Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  static Future<void> _onCreate(Database db, int version) async {
    for (final statement in _v1) {
      await db.execute(statement);
    }
  }

  static Future<void> _onUpgrade(Database db, int from, int to) async {
    // Version 1 is the initial schema; migrations land here as the app grows.
    // Each step must be additive and idempotent enough to survive a retry.
  }

  Future<void> close() => db.close();

  static const List<String> _v1 = [
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

    // At most one active trip, enforced by the database rather than trusted to
    // application code. A partial unique index is the cheapest way to make the
    // invariant unbreakable — a second insert fails loudly instead of quietly
    // producing two "current" lists.
    '''
    CREATE UNIQUE INDEX idx_single_active_trip
      ON trips(status) WHERE status = 'active'
    ''',

    // Ranks autocomplete: things bought often and recently come first.
    '''
    CREATE INDEX idx_products_ranking
      ON products(usage_count DESC, last_used_at DESC)
    ''',
    'CREATE INDEX idx_trip_items_trip ON trip_items(trip_id, sort_order)',
    'CREATE INDEX idx_trips_history ON trips(status, completed_at DESC)',
  ];
}
