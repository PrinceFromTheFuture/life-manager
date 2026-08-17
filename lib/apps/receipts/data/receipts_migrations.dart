import 'package:shopping_list/core/db/migration.dart';

/// Schema owned by the receipts app.
///
/// New in this build, so there is nothing to adopt — no `adoptIfTableExists`.
const ModuleMigrations receiptsMigrations = ModuleMigrations(
  moduleId: 'receipts',
  migrations: [
    Migration(
      version: 1,
      statements: [
        '''
        CREATE TABLE IF NOT EXISTS expense_categories (
          id   INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT    NOT NULL UNIQUE,
          sort INTEGER NOT NULL DEFAULT 0
        )
        ''',
        '''
        CREATE TABLE IF NOT EXISTS accounts (
          id    INTEGER PRIMARY KEY AUTOINCREMENT,
          name  TEXT    NOT NULL UNIQUE,
          kind  TEXT    NOT NULL DEFAULT 'other',
          last4 TEXT,
          sort  INTEGER NOT NULL DEFAULT 0
        )
        ''',
        '''
        CREATE TABLE IF NOT EXISTS expenses (
          id             INTEGER PRIMARY KEY AUTOINCREMENT,
          occurred_at    INTEGER NOT NULL,
          amount_minor   INTEGER NOT NULL,
          currency       TEXT    NOT NULL DEFAULT 'ILS',
          merchant       TEXT,
          description    TEXT,
          category_id    INTEGER REFERENCES expense_categories(id) ON DELETE SET NULL,
          account_id     INTEGER REFERENCES accounts(id) ON DELETE SET NULL,
          location_label TEXT,
          latitude       REAL,
          longitude      REAL,

          -- A receipt is not optional. Enforced here rather than only in the
          -- form, so no future code path can create an expense without one.
          receipt_path   TEXT    NOT NULL,

          source         TEXT    NOT NULL DEFAULT 'manual'
                                 CHECK (source IN ('manual', 'scanned')),
          ocr_raw        TEXT,
          ocr_model      TEXT,
          created_at     INTEGER NOT NULL,
          updated_at     INTEGER NOT NULL
        )
        ''',

        // Which category a given shop usually falls into. This is what lets
        // the form preselect "Groceries" the fourth time you log Rami Levy,
        // instead of making you pick from ten chips every single time.
        '''
        CREATE TABLE IF NOT EXISTS merchant_categories (
          merchant_normalized TEXT    NOT NULL,
          category_id         INTEGER NOT NULL
                                      REFERENCES expense_categories(id) ON DELETE CASCADE,
          uses                INTEGER NOT NULL DEFAULT 0,
          last_used_at        INTEGER,
          PRIMARY KEY (merchant_normalized, category_id)
        )
        ''',

        '''
        CREATE INDEX IF NOT EXISTS idx_expenses_recent
          ON expenses(occurred_at DESC)
        ''',
        '''
        CREATE INDEX IF NOT EXISTS idx_expenses_category
          ON expenses(category_id, occurred_at DESC)
        ''',
        '''
        CREATE INDEX IF NOT EXISTS idx_merchant_ranking
          ON merchant_categories(merchant_normalized, uses DESC, last_used_at DESC)
        ''',

        // Seeds. `OR IGNORE` so renaming or deleting one of these later is not
        // undone by a reinstall of the same migration.
        '''
        INSERT OR IGNORE INTO expense_categories (name, sort) VALUES
          ('Groceries', 0), ('Eating out', 1), ('Transport', 2),
          ('Fuel', 3), ('Pharmacy', 4), ('Home', 5),
          ('Utilities', 6), ('Clothing', 7), ('Entertainment', 8),
          ('Other', 9)
        ''',
        '''
        INSERT OR IGNORE INTO accounts (name, kind, sort) VALUES
          ('Cash', 'cash', 0), ('Credit card', 'card', 1), ('Debit card', 'card', 2)
        ''',
      ],
    ),
    Migration(
      version: 2,
      statements: [
        // Existing slips stay personal. The flag is opt-in on each expense,
        // not inferred from category — Fuel can be either.
        '''
        ALTER TABLE expenses ADD COLUMN is_business INTEGER NOT NULL DEFAULT 0
        ''',
      ],
    ),
  ],
);
