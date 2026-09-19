import 'package:sqflite/sqflite.dart';

import 'package:shopping_list/core/db/migration.dart';

/// Applies each module's schema independently.
///
/// Replaces sqflite's single global `version:` / `onUpgrade`, which requires
/// every mini-app to edit one shared file and agree on one counter. Here each
/// module records its own version in `schema_versions`, so a new app ships its
/// migrations in its own folder and the core is never touched — and a broken
/// migration in one module cannot strand another.
abstract final class Migrator {
  static const String versionsTable = 'schema_versions';

  static Future<void> run(Database db, List<ModuleMigrations> modules) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $versionsTable (
        module_id TEXT PRIMARY KEY,
        version   INTEGER NOT NULL
      )
    ''');

    for (final module in modules) {
      var current = await _versionOf(db, module.moduleId);

      // Databases created before this migrator existed have the tables but no
      // version row. Adopt them at their known baseline rather than replaying
      // a CREATE TABLE over live data.
      if (current == 0 && module.adoptIfTableExists != null) {
        if (await _tableExists(db, module.adoptIfTableExists!)) {
          current = module.adoptAtVersion;
          await _setVersion(db, module.moduleId, current);
        }
      }

      final pending = module.migrations.where((m) => m.version > current).toList()
        ..sort((a, b) => a.version.compareTo(b.version));

      for (final migration in pending) {
        // Each step commits atomically with its own version bump, so an
        // interrupted upgrade resumes from the last completed step rather than
        // replaying one that already half-applied.
        await db.transaction((txn) async {
          for (final statement in migration.statements) {
            await txn.execute(statement);
          }
          await txn.insert(
            versionsTable,
            {'module_id': module.moduleId, 'version': migration.version},
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        });
      }
    }
  }

  static Future<int> _versionOf(DatabaseExecutor db, String moduleId) async {
    final rows = await db.query(
      versionsTable,
      columns: ['version'],
      where: 'module_id = ?',
      whereArgs: [moduleId],
      limit: 1,
    );
    return rows.isEmpty ? 0 : rows.first['version']! as int;
  }

  static Future<void> _setVersion(
    DatabaseExecutor db,
    String moduleId,
    int version,
  ) =>
      db.insert(
        versionsTable,
        {'module_id': moduleId, 'version': version},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  static Future<bool> _tableExists(DatabaseExecutor db, String name) async {
    final rows = await db.rawQuery(
      "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ? LIMIT 1",
      [name],
    );
    return rows.isNotEmpty;
  }

  /// Exposed for tests and diagnostics.
  static Future<Map<String, int>> versions(DatabaseExecutor db) async {
    final rows = await db.query(versionsTable);
    return {
      for (final r in rows) r['module_id']! as String: r['version']! as int,
    };
  }
}
