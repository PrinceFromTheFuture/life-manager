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

    // The financial manager. An account is where money actually sits; a
    // payment method is a way of reaching it, and the two are separate because
    // one account can be reached three ways (transfer, debit card, credit
    // card) with completely different timing.
    Migration(
      version: 3,
      statements: [
        // An account now carries a starting point, because a balance derived
        // from entries alone is only correct if the ledger goes back to the
        // day the account was opened, which it never does.
        '''
        ALTER TABLE accounts ADD COLUMN opening_minor INTEGER NOT NULL DEFAULT 0
        ''',
        'ALTER TABLE accounts ADD COLUMN opened_at INTEGER',
        // Archived rather than deleted: a closed card still owns the history
        // of everything charged to it.
        'ALTER TABLE accounts ADD COLUMN archived_at INTEGER',

        '''
        CREATE TABLE IF NOT EXISTS payment_methods (
          id                 INTEGER PRIMARY KEY AUTOINCREMENT,
          account_id         INTEGER NOT NULL
                                     REFERENCES accounts(id) ON DELETE CASCADE,
          name               TEXT    NOT NULL,

          -- 'direct' leaves the account at the moment of purchase. 'indirect'
          -- collects until the statement day and then leaves in one go.
          settlement         TEXT    NOT NULL DEFAULT 'direct'
                                     CHECK (settlement IN ('direct', 'indirect')),

          -- Both only meaningful for 'indirect', and both optional even then:
          -- plenty of cards have no limit worth tracking.
          statement_day      INTEGER,
          credit_limit_minor INTEGER,

          last4              TEXT,
          sort               INTEGER NOT NULL DEFAULT 0,
          archived_at        INTEGER,
          created_at         INTEGER NOT NULL DEFAULT 0
        )
        ''',

        '''
        CREATE TABLE IF NOT EXISTS recurring_rules (
          id                INTEGER PRIMARY KEY AUTOINCREMENT,
          kind              TEXT    NOT NULL DEFAULT 'expense'
                                    CHECK (kind IN ('expense', 'income')),
          name              TEXT    NOT NULL,
          amount_minor      INTEGER NOT NULL,
          category_id       INTEGER REFERENCES expense_categories(id) ON DELETE SET NULL,
          payment_method_id INTEGER REFERENCES payment_methods(id) ON DELETE SET NULL,
          account_id        INTEGER REFERENCES accounts(id) ON DELETE SET NULL,
          day_of_month      INTEGER NOT NULL,
          is_business       INTEGER NOT NULL DEFAULT 0,
          note              TEXT,
          starts_on         INTEGER NOT NULL,
          ends_on           INTEGER,

          -- The high-water mark of the sweep. Everything about idempotency
          -- hangs off this one column: the materializer only ever looks
          -- forward from here, so running it twice in a day writes nothing the
          -- second time.
          last_run_on       INTEGER,

          active            INTEGER NOT NULL DEFAULT 1,
          created_at        INTEGER NOT NULL
        )
        ''',

        '''
        CREATE TABLE IF NOT EXISTS incomes (
          id                INTEGER PRIMARY KEY AUTOINCREMENT,
          occurred_at       INTEGER NOT NULL,
          amount_minor      INTEGER NOT NULL,
          source_name       TEXT    NOT NULL,
          account_id        INTEGER REFERENCES accounts(id) ON DELETE SET NULL,
          note              TEXT,
          recurring_rule_id INTEGER REFERENCES recurring_rules(id) ON DELETE SET NULL,
          created_at        INTEGER NOT NULL
        )
        ''',

        // Append-only. Nothing in the app issues an UPDATE or a DELETE against
        // this table: a correction is a new row of kind 'reversal' pointing at
        // the row it undoes. That is what makes a balance reproducible from
        // history rather than a number someone edited.
        '''
        CREATE TABLE IF NOT EXISTS account_entries (
          id           INTEGER PRIMARY KEY AUTOINCREMENT,
          account_id   INTEGER NOT NULL
                               REFERENCES accounts(id) ON DELETE CASCADE,
          occurred_at  INTEGER NOT NULL,

          -- Signed. Negative leaves the account, positive arrives.
          amount_minor INTEGER NOT NULL,

          kind         TEXT    NOT NULL
                               CHECK (kind IN ('opening', 'expense', 'income',
                                               'settlement', 'reversal',
                                               'adjustment')),
          ref_table    TEXT,
          ref_id       INTEGER,
          reverses_id  INTEGER REFERENCES account_entries(id),
          note         TEXT,
          created_at   INTEGER NOT NULL
        )
        ''',

        'ALTER TABLE expenses ADD COLUMN payment_method_id INTEGER',
        'ALTER TABLE expenses ADD COLUMN installments INTEGER NOT NULL DEFAULT 1',
        // Annual nominal rate in basis points. 600 is 6% a year.
        'ALTER TABLE expenses ADD COLUMN interest_bp INTEGER NOT NULL DEFAULT 0',
        'ALTER TABLE expenses ADD COLUMN recurring_rule_id INTEGER',

        '''
        CREATE INDEX IF NOT EXISTS idx_payment_methods_account
          ON payment_methods(account_id, sort)
        ''',
        '''
        CREATE INDEX IF NOT EXISTS idx_account_entries_account
          ON account_entries(account_id, occurred_at, id)
        ''',
        // The sweep asks "has this statement already settled?" on every launch.
        '''
        CREATE INDEX IF NOT EXISTS idx_account_entries_ref
          ON account_entries(ref_table, ref_id, kind)
        ''',
        '''
        CREATE INDEX IF NOT EXISTS idx_expenses_method
          ON expenses(payment_method_id, occurred_at DESC)
        ''',
        '''
        CREATE INDEX IF NOT EXISTS idx_incomes_recent
          ON incomes(occurred_at DESC)
        ''',

        // --------------------------------------------------------- backfill

        // Every account that already exists gets one direct payment method
        // carrying its name, so nothing in the app has to cope with an account
        // that cannot be paid from.
        '''
        INSERT INTO payment_methods
          (account_id, name, settlement, last4, sort, created_at)
        SELECT id, name, 'direct', last4, 0, CAST(strftime('%s','now') AS INTEGER) * 1000
        FROM accounts
        ''',

        // Existing slips keep their "paid with" by pointing at the method that
        // was just created for their account.
        '''
        UPDATE expenses SET payment_method_id = (
          SELECT pm.id FROM payment_methods pm
          WHERE pm.account_id = expenses.account_id
          ORDER BY pm.id LIMIT 1
        )
        WHERE account_id IS NOT NULL
        ''',

        // And every one of those slips becomes a ledger entry, so a balance is
        // meaningful the first time Accounts is opened rather than only after
        // the next purchase. All backfilled methods are direct, so every one of
        // these really did leave the account when it happened.
        '''
        INSERT INTO account_entries
          (account_id, occurred_at, amount_minor, kind, ref_table, ref_id, created_at)
        SELECT account_id, occurred_at, -amount_minor, 'expense', 'expenses', id, created_at
        FROM expenses
        WHERE account_id IS NOT NULL
        ''',
      ],
    ),

    // Each category owns one stamp-pad ink so statistics can tell them apart.
    // Ids are stable names, not hex, so a colour can be retuned without
    // rewriting anyone's database.
    Migration(
      version: 4,
      statements: [
        '''
        ALTER TABLE expense_categories ADD COLUMN ink TEXT NOT NULL DEFAULT 'ledger'
        ''',
        '''
        UPDATE expense_categories SET ink = CASE name
          WHEN 'Groceries' THEN 'pine'
          WHEN 'Eating out' THEN 'carmine'
          WHEN 'Transport' THEN 'slate'
          WHEN 'Fuel' THEN 'scorch'
          WHEN 'Pharmacy' THEN 'violet'
          WHEN 'Home' THEN 'ledger'
          WHEN 'Utilities' THEN 'teal'
          WHEN 'Clothing' THEN 'iron'
          WHEN 'Entertainment' THEN 'mustard'
          WHEN 'Other' THEN 'wine'
          ELSE ink
        END
        ''',
        '''
        UPDATE expense_categories SET ink = CASE (id % 10)
          WHEN 0 THEN 'pine'
          WHEN 1 THEN 'carmine'
          WHEN 2 THEN 'slate'
          WHEN 3 THEN 'scorch'
          WHEN 4 THEN 'violet'
          WHEN 5 THEN 'ledger'
          WHEN 6 THEN 'teal'
          WHEN 7 THEN 'iron'
          WHEN 8 THEN 'mustard'
          ELSE 'wine'
        END
        WHERE name NOT IN (
          'Groceries', 'Eating out', 'Transport', 'Fuel', 'Pharmacy',
          'Home', 'Utilities', 'Clothing', 'Entertainment', 'Other'
        )
        ''',
      ],
    ),

    // Each account owns a printed mark — icon plus stamp-pad ink — so the
    // passbook pages can be told apart at a glance.
    Migration(
      version: 5,
      statements: [
        '''
        ALTER TABLE accounts ADD COLUMN mark TEXT NOT NULL DEFAULT 'vault'
        ''',
        '''
        UPDATE accounts SET mark = CASE
          WHEN name = 'Cash' THEN 'wallet'
          WHEN name = 'Credit card' THEN 'plate'
          WHEN name = 'Debit card' THEN 'atm'
          WHEN kind = 'cash' THEN 'wallet'
          WHEN kind = 'card' THEN 'plate'
          WHEN kind = 'bank' THEN 'vault'
          ELSE 'coins'
        END
        ''',
      ],
    ),

    // Named groups of accounts. "To spend" is not the same number as
    // "net worth"; the page shows one group at a time rather than pretending
    // every pot is equally reachable.
    Migration(
      version: 6,
      statements: [
        '''
        CREATE TABLE account_views (
          id   INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT    NOT NULL,
          sort INTEGER NOT NULL DEFAULT 0
        )
        ''',
        '''
        CREATE TABLE account_view_members (
          view_id    INTEGER NOT NULL
                             REFERENCES account_views(id) ON DELETE CASCADE,
          account_id INTEGER NOT NULL
                             REFERENCES accounts(id) ON DELETE CASCADE,
          PRIMARY KEY (view_id, account_id)
        )
        ''',
        '''
        CREATE TABLE account_view_state (
          id             INTEGER PRIMARY KEY CHECK (id = 1),
          active_view_id INTEGER REFERENCES account_views(id) ON DELETE SET NULL
        )
        ''',
        '''
        INSERT INTO account_view_state (id, active_view_id) VALUES (1, NULL)
        ''',
      ],
    ),
  ],
);
