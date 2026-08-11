import 'package:sqflite/sqflite.dart';

import 'package:shopping_list/core/db/core_migrations.dart';
import 'package:shopping_list/core/db/migration.dart';
import 'package:shopping_list/core/db/migrator.dart';

/// Opens the shared database and hands schema management to [Migrator].
///
/// Every mini-app stores its tables here rather than in its own file. One
/// database means the activity feed can be a single query and future apps can
/// genuinely relate to each other, which is the point of the whole
/// restructure.
///
/// Note there is no `version:` or `onCreate:` — sqflite's global version
/// counter is deliberately unused, because it forces all modules to coordinate
/// through one number. See [Migrator].
class AppDatabase {
  AppDatabase._(this.db);

  final Database db;

  static const String fileName = 'shopping_list.db';

  static Future<AppDatabase> open({
    required List<ModuleMigrations> modules,
    DatabaseFactory? factory,
    String? path,
  }) async {
    final f = factory ?? databaseFactory;
    final dbPath = path ?? '${await f.getDatabasesPath()}/$fileName';

    final db = await f.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(onConfigure: _onConfigure),
    );

    await Migrator.run(db, [coreMigrations, ...modules]);
    return AppDatabase._(db);
  }

  /// Foreign keys are off by default in SQLite and must be enabled per
  /// connection, before any migration runs.
  static Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> close() => db.close();
}
