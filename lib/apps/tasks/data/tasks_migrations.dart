import 'package:shopping_list/core/db/migration.dart';

/// Schema owned by the tasks app.
const ModuleMigrations tasksMigrations = ModuleMigrations(
  moduleId: 'tasks',
  migrations: [
    Migration(
      version: 1,
      statements: [
        '''
        CREATE TABLE IF NOT EXISTS tasks_projects (
          id           INTEGER PRIMARY KEY AUTOINCREMENT,
          name         TEXT    NOT NULL,
          ink_id       TEXT    NOT NULL,
          icon_id      TEXT    NOT NULL,
          sort         INTEGER NOT NULL DEFAULT 0,
          archived_at  INTEGER,
          created_at   INTEGER NOT NULL,
          updated_at   INTEGER NOT NULL
        )
        ''',
        '''
        CREATE TABLE IF NOT EXISTS tasks_items (
          id             INTEGER PRIMARY KEY AUTOINCREMENT,
          project_id     INTEGER NOT NULL
                                 REFERENCES tasks_projects(id) ON DELETE CASCADE,
          title          TEXT    NOT NULL,
          notes          TEXT,
          due_at         INTEGER,
          urgency        TEXT    NOT NULL DEFAULT 'later',
          snoozed_until  INTEGER,
          completed_at   INTEGER,
          repeat         TEXT    NOT NULL DEFAULT 'none',
          created_at     INTEGER NOT NULL,
          updated_at     INTEGER NOT NULL
        )
        ''',
        '''
        CREATE INDEX IF NOT EXISTS idx_tasks_items_project
          ON tasks_items(project_id, completed_at)
        ''',
        '''
        CREATE INDEX IF NOT EXISTS idx_tasks_items_tray
          ON tasks_items(completed_at, snoozed_until, due_at, urgency)
        ''',
      ],
    ),
  ],
);
