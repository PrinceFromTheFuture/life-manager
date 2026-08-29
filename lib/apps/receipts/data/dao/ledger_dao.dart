import 'package:sqflite/sqflite.dart';

import 'package:shopping_list/apps/receipts/data/models/account_entry.dart';

/// Reads and appends to `account_entries`.
///
/// There is deliberately no `update` and no `delete` on this class. A ledger
/// that can be edited is just a number with extra steps; the only way to change
/// what an account holds is to append another line.
class LedgerDao {
  LedgerDao(this._db);

  final DatabaseExecutor _db;

  /// Oldest first, which is the order a running balance has to be accumulated
  /// in. The screen reverses it for display.
  Future<List<AccountEntry>> entriesFor(int accountId, {int? limit}) async {
    final rows = await _db.query(
      'account_entries',
      where: 'account_id = ?',
      whereArgs: [accountId],
      orderBy: 'occurred_at ASC, id ASC',
      limit: limit,
    );
    return rows.map(AccountEntry.fromMap).toList();
  }

  /// Sum of every entry against every account, keyed by account id.
  ///
  /// One query rather than one per account: the accounts screen needs all of
  /// them at once, and a loop of SUMs there was the obvious way to make a
  /// four-account list feel slow.
  Future<Map<int, int>> sums() async {
    final rows = await _db.rawQuery(
      'SELECT account_id, COALESCE(SUM(amount_minor), 0) AS total '
      'FROM account_entries GROUP BY account_id',
    );
    return {
      for (final row in rows) row['account_id']! as int: row['total']! as int,
    };
  }

  /// Sum of entries on or after [from], keyed by account. Used for today's
  /// move on the accounts screen without walking every line.
  Future<Map<int, int>> sumsSince(DateTime from) async {
    final rows = await _db.rawQuery(
      'SELECT account_id, COALESCE(SUM(amount_minor), 0) AS total '
      'FROM account_entries WHERE occurred_at >= ? GROUP BY account_id',
      [from.millisecondsSinceEpoch],
    );
    return {
      for (final row in rows) row['account_id']! as int: row['total']! as int,
    };
  }

  Future<int> sumFor(int accountId) async =>
      Sqflite.firstIntValue(
        await _db.rawQuery(
          'SELECT COALESCE(SUM(amount_minor), 0) FROM account_entries '
          'WHERE account_id = ?',
          [accountId],
        ),
      ) ??
      0;

  Future<AccountEntry> append(AccountEntry entry) async {
    final id = await _db.insert('account_entries', entry.toMap());
    return AccountEntry(
      id: id,
      accountId: entry.accountId,
      occurredAt: entry.occurredAt,
      amountMinor: entry.amountMinor,
      kind: entry.kind,
      refTable: entry.refTable,
      refId: entry.refId,
      reversesId: entry.reversesId,
      note: entry.note,
      createdAt: entry.createdAt,
    );
  }

  /// The live (unreversed) entries written for one source record.
  ///
  /// Used when an expense is edited or deleted: whatever it posted has to be
  /// reversed, and an entry that already has a reversal pointing at it must not
  /// be reversed twice.
  Future<List<AccountEntry>> liveEntriesFor({
    required String refTable,
    required int refId,
  }) async {
    final rows = await _db.rawQuery(
      '''
      SELECT e.* FROM account_entries e
      WHERE e.ref_table = ? AND e.ref_id = ? AND e.kind <> 'reversal'
        AND NOT EXISTS (
          SELECT 1 FROM account_entries r WHERE r.reverses_id = e.id
        )
      ''',
      [refTable, refId],
    );
    return rows.map(AccountEntry.fromMap).toList();
  }

  /// Corrects the cached label on every line one record posted.
  ///
  /// The note is a copy of the source record's title, held so the passbook
  /// reads without a join. Renaming a shop moves no money, so it must not
  /// append a cancelling pair — and the old name must not linger either. No
  /// amount is touched here; changing one still takes a new line.
  Future<void> correctNote({
    required String refTable,
    required int refId,
    required String note,
  }) =>
      _db.update(
        'account_entries',
        {'note': note},
        where: 'ref_table = ? AND ref_id = ?',
        whereArgs: [refTable, refId],
      );

  /// When this method's statement last settled, so the sweep only considers
  /// cycles that closed after it.
  Future<DateTime?> lastSettlementAt(int paymentMethodId) async {
    final rows = await _db.query(
      'account_entries',
      columns: ['occurred_at'],
      where: "kind = 'settlement' AND ref_table = 'payment_methods' "
          'AND ref_id = ?',
      whereArgs: [paymentMethodId],
      orderBy: 'occurred_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return DateTime.fromMillisecondsSinceEpoch(
      rows.first['occurred_at']! as int,
    );
  }

  /// Whether a statement has already been posted for this method on this date.
  /// The sweep asks this on every launch, which is what makes it idempotent.
  Future<bool> hasSettlement({
    required int paymentMethodId,
    required DateTime settlesOn,
  }) async {
    final count = Sqflite.firstIntValue(
      await _db.rawQuery(
        "SELECT COUNT(*) FROM account_entries WHERE kind = 'settlement' "
        "AND ref_table = 'payment_methods' AND ref_id = ? AND occurred_at = ?",
        [paymentMethodId, settlesOn.millisecondsSinceEpoch],
      ),
    );
    return (count ?? 0) > 0;
  }
}
