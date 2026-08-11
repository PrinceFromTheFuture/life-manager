/// One step in a module's schema history.
///
/// Steps are applied in ascending [version] order and never edited once
/// shipped — a released migration has already run on a real database, so
/// changing it makes two installs disagree about what version 3 means.
class Migration {
  const Migration({required this.version, required this.statements});

  /// Module-local, starting at 1. Deliberately *not* a global counter: a
  /// global version forces every app to coordinate through one number, which
  /// is exactly what stops new apps being self-contained.
  final int version;

  final List<String> statements;
}

/// The complete schema owned by one module.
class ModuleMigrations {
  const ModuleMigrations({
    required this.moduleId,
    required this.migrations,
    this.adoptIfTableExists,
    this.adoptAtVersion = 1,
  });

  /// Key in `schema_versions`. Usually the `MiniApp.id`; `core` for shared
  /// tables.
  final String moduleId;

  final List<Migration> migrations;

  /// Adoption escape hatch for databases that predate this migrator.
  ///
  /// The groceries tables on the phone were created by sqflite's own
  /// `onCreate`, so they exist but have no `schema_versions` row. Without
  /// this, the migrator would see version 0 and try to `CREATE TABLE` over
  /// live data. If this table is present and the module is unversioned, the
  /// module is recorded at [adoptAtVersion] and its earlier migrations are
  /// skipped as already applied.
  final String? adoptIfTableExists;

  final int adoptAtVersion;

  int get latestVersion =>
      migrations.isEmpty ? 0 : migrations.map((m) => m.version).reduce(
            (a, b) => a > b ? a : b,
          );
}
