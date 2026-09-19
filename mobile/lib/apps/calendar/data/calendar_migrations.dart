import 'package:shopping_list/core/db/migration.dart';

/// Schema owned by the calendar app.
///
/// New in this build, so there is nothing to adopt — no `adoptIfTableExists`.
const ModuleMigrations calendarMigrations = ModuleMigrations(
  moduleId: 'calendar',
  migrations: [
    Migration(
      version: 1,
      statements: [
        '''
        CREATE TABLE IF NOT EXISTS calendar_locations (
          id          INTEGER PRIMARY KEY AUTOINCREMENT,
          title       TEXT    NOT NULL,
          icon_id     TEXT    NOT NULL,
          ink_id      TEXT    NOT NULL,
          latitude    REAL    NOT NULL,
          longitude   REAL    NOT NULL,
          created_at  INTEGER NOT NULL
        )
        ''',
        '''
        CREATE TABLE IF NOT EXISTS calendar_series (
          id                INTEGER PRIMARY KEY AUTOINCREMENT,
          title             TEXT    NOT NULL,
          location_id       INTEGER REFERENCES calendar_locations(id) ON DELETE SET NULL,
          start_minutes     INTEGER NOT NULL,
          duration_minutes  INTEGER NOT NULL,
          freq              TEXT    NOT NULL,
          interval          INTEGER NOT NULL DEFAULT 1,
          weekdays          INTEGER NOT NULL DEFAULT 0,
          month_day         INTEGER NOT NULL DEFAULT 1,
          starts_on         INTEGER NOT NULL,
          ends_on           INTEGER,
          active            INTEGER NOT NULL DEFAULT 1,
          created_at        INTEGER NOT NULL
        )
        ''',
        '''
        CREATE TABLE IF NOT EXISTS calendar_blocks (
          id                INTEGER PRIMARY KEY AUTOINCREMENT,
          title             TEXT    NOT NULL,
          starts_at         INTEGER NOT NULL,
          duration_minutes  INTEGER NOT NULL,
          location_id       INTEGER REFERENCES calendar_locations(id) ON DELETE SET NULL,
          created_at        INTEGER NOT NULL
        )
        ''',
        '''
        CREATE TABLE IF NOT EXISTS calendar_overrides (
          id                INTEGER PRIMARY KEY AUTOINCREMENT,
          series_id         INTEGER NOT NULL
                                    REFERENCES calendar_series(id) ON DELETE CASCADE,
          original_start    INTEGER NOT NULL,
          kind              TEXT    NOT NULL,
          starts_at         INTEGER,
          duration_minutes  INTEGER,
          location_id       INTEGER REFERENCES calendar_locations(id) ON DELETE SET NULL,
          title             TEXT,
          created_at        INTEGER NOT NULL,
          UNIQUE(series_id, original_start)
        )
        ''',
        '''
        CREATE INDEX IF NOT EXISTS idx_calendar_blocks_starts
          ON calendar_blocks(starts_at)
        ''',
        '''
        CREATE INDEX IF NOT EXISTS idx_calendar_series_active
          ON calendar_series(active, starts_on)
        ''',
        '''
        CREATE INDEX IF NOT EXISTS idx_calendar_overrides_series
          ON calendar_overrides(series_id, original_start)
        ''',
      ],
    ),
    Migration(
      version: 2,
      statements: [
        'ALTER TABLE calendar_blocks ADD COLUMN note TEXT',
        'ALTER TABLE calendar_blocks ADD COLUMN ink_id TEXT',
        'ALTER TABLE calendar_blocks ADD COLUMN icon_id TEXT',
        'ALTER TABLE calendar_overrides ADD COLUMN note TEXT',
        'ALTER TABLE calendar_overrides ADD COLUMN ink_id TEXT',
        'ALTER TABLE calendar_overrides ADD COLUMN icon_id TEXT',
      ],
    ),
  ],
);
