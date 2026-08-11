import 'package:shopping_list/core/db/migration.dart';

/// Schema owned by the shell rather than by any one mini-app.
///
/// Adoption note: `adoptIfTableExists` is deliberately **not** set here. The
/// activity table is new in this version, so even a database that predates the
/// migrator must genuinely run migration 1 to get it.
const ModuleMigrations coreMigrations = ModuleMigrations(
  moduleId: 'core',
  migrations: [
    Migration(
      version: 1,
      statements: [
        '''
        CREATE TABLE IF NOT EXISTS activity (
          id           INTEGER PRIMARY KEY AUTOINCREMENT,
          app_id       TEXT    NOT NULL,
          kind         TEXT    NOT NULL,
          title        TEXT    NOT NULL,
          subtitle     TEXT,
          amount_minor INTEGER,
          occurred_at  INTEGER NOT NULL,
          ref_table    TEXT,
          ref_id       INTEGER
        )
        ''',

        // The feed is always "newest first, then grouped by day", so this is
        // the only ordering it ever needs.
        '''
        CREATE INDEX IF NOT EXISTS idx_activity_recent
          ON activity(occurred_at DESC)
        ''',

        // Lets a module clean up its own entries when a record is deleted,
        // without scanning the whole table.
        '''
        CREATE INDEX IF NOT EXISTS idx_activity_ref
          ON activity(app_id, ref_table, ref_id)
        ''',
      ],
    ),
  ],
);
