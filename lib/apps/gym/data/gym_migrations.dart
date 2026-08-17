import 'package:shopping_list/core/db/migration.dart';

/// Schema owned by the gym app.
///
/// New in this build, so there is nothing to adopt — no `adoptIfTableExists`.
const ModuleMigrations gymMigrations = ModuleMigrations(
  moduleId: 'gym',
  migrations: [
    Migration(
      version: 1,
      statements: [
        '''
        CREATE TABLE IF NOT EXISTS gym_exercises (
          id             INTEGER PRIMARY KEY AUTOINCREMENT,
          name           TEXT    NOT NULL UNIQUE,
          on_rack        INTEGER NOT NULL DEFAULT 1,
          last_weight_g  INTEGER,
          last_reps      INTEGER,
          sort           INTEGER NOT NULL DEFAULT 0
        )
        ''',
        '''
        CREATE TABLE IF NOT EXISTS gym_sets (
          id           INTEGER PRIMARY KEY AUTOINCREMENT,
          exercise_id  INTEGER NOT NULL
                               REFERENCES gym_exercises(id) ON DELETE CASCADE,
          occurred_at  INTEGER NOT NULL,
          reps         INTEGER NOT NULL,
          weight_g     INTEGER NOT NULL,
          created_at   INTEGER NOT NULL
        )
        ''',
        '''
        CREATE INDEX IF NOT EXISTS idx_gym_sets_day
          ON gym_sets(occurred_at DESC)
        ''',
        '''
        CREATE INDEX IF NOT EXISTS idx_gym_sets_exercise
          ON gym_sets(exercise_id, occurred_at DESC)
        ''',

        // A starter rack. `OR IGNORE` so renaming or deleting one of these
        // later is not undone by a reinstall of the same migration.
        '''
        INSERT OR IGNORE INTO gym_exercises (name, on_rack, sort) VALUES
          ('Squat', 1, 0),
          ('Bench press', 1, 1),
          ('Deadlift', 1, 2),
          ('Overhead press', 1, 3),
          ('Barbell row', 1, 4),
          ('Pull-up', 1, 5),
          ('Romanian deadlift', 0, 6),
          ('Lunge', 0, 7),
          ('Hip thrust', 0, 8),
          ('Plank', 0, 9)
        ''',
      ],
    ),
  ],
);
