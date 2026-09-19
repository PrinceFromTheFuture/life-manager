import 'package:sqflite/sqflite.dart';

import 'package:shopping_list/apps/receipts/data/models/recurring_rule.dart';

class RecurringDao {
  RecurringDao(this._db);

  final DatabaseExecutor _db;

  /// Grouped by the day they land on, because that is how anyone thinks about
  /// standing orders: the 1st, the 10th, the 15th.
  Future<List<RecurringRule>> all() async {
    final rows = await _db.query(
      'recurring_rules',
      orderBy: 'day_of_month ASC, name ASC',
    );
    return rows.map(RecurringRule.fromMap).toList();
  }

  Future<List<RecurringRule>> active() async {
    final rows = await _db.query(
      'recurring_rules',
      where: 'active = 1',
      orderBy: 'day_of_month ASC, name ASC',
    );
    return rows.map(RecurringRule.fromMap).toList();
  }

  Future<RecurringRule?> byId(int id) async {
    final rows = await _db.query(
      'recurring_rules',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : RecurringRule.fromMap(rows.first);
  }

  Future<RecurringRule> insert(RecurringRule rule) async {
    final id = await _db.insert('recurring_rules', rule.toMap());
    return rule.copyWith(id: id);
  }

  Future<void> update(RecurringRule rule) => _db.update(
        'recurring_rules',
        rule.toMap(),
        where: 'id = ?',
        whereArgs: [rule.id],
      );

  Future<void> markRun(int id, DateTime on) => _db.update(
        'recurring_rules',
        {'last_run_on': on.millisecondsSinceEpoch},
        where: 'id = ?',
        whereArgs: [id],
      );

  Future<void> setActive(int id, {required bool active}) => _db.update(
        'recurring_rules',
        {'active': active ? 1 : 0},
        where: 'id = ?',
        whereArgs: [id],
      );

  /// Deletes the rule. Slips it already wrote keep their `recurring_rule_id`
  /// and simply stop resolving to a name — the money still happened.
  Future<void> delete(int id) =>
      _db.delete('recurring_rules', where: 'id = ?', whereArgs: [id]);

  /// What every expense rule adds up to in a month, for the section summary.
  Future<int> monthlyTotal() async =>
      Sqflite.firstIntValue(
        await _db.rawQuery(
          'SELECT COALESCE(SUM(amount_minor), 0) FROM recurring_rules '
          "WHERE kind = 'expense'",
        ),
      ) ??
      0;

  /// Recurring templates that already have a slip or an income in [from, to).
  ///
  /// The recurring page uses this for the current calendar month: no row in
  /// this set is still missing.
  Future<Set<int>> linkedRuleIdsBetween(DateTime from, DateTime to) async {
    final fromMs = from.millisecondsSinceEpoch;
    final toMs = to.millisecondsSinceEpoch;
    final rows = await _db.rawQuery(
      '''
      SELECT recurring_rule_id AS id FROM expenses
      WHERE recurring_rule_id IS NOT NULL
        AND occurred_at >= ? AND occurred_at < ?
      UNION
      SELECT recurring_rule_id AS id FROM incomes
      WHERE recurring_rule_id IS NOT NULL
        AND occurred_at >= ? AND occurred_at < ?
      ''',
      [fromMs, toMs, fromMs, toMs],
    );
    return {
      for (final row in rows)
        if (row['id'] != null) row['id'] as int,
    };
  }
}
