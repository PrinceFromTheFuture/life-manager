import 'package:sqflite/sqflite.dart';

import 'package:shopping_list/apps/receipts/data/models/expense.dart';
import 'package:shopping_list/apps/receipts/data/models/month_kind_totals.dart';
import 'package:shopping_list/core/util/normalize.dart';

class ExpenseDao {
  ExpenseDao(this._db);

  final DatabaseExecutor _db;

  Future<List<Expense>> recent({int limit = 200, int offset = 0}) async {
    final rows = await _db.query(
      'expenses',
      orderBy: 'occurred_at DESC, id DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(Expense.fromMap).toList();
  }

  /// Every expense in `[from, to)`, for the month selector on the main list
  /// and for statistics. A dedicated query rather than filtering [recent]'s
  /// capped result — a month several pages back must not silently come up
  /// empty just because it fell outside that cap.
  Future<List<Expense>> between(DateTime from, DateTime to) async {
    final rows = await _db.query(
      'expenses',
      where: 'occurred_at >= ? AND occurred_at < ?',
      whereArgs: [from.millisecondsSinceEpoch, to.millisecondsSinceEpoch],
      orderBy: 'occurred_at DESC, id DESC',
    );
    return rows.map(Expense.fromMap).toList();
  }

  Future<Expense?> byId(int id) async {
    final rows =
        await _db.query('expenses', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Expense.fromMap(rows.first);
  }

  Future<Expense> insert(Expense expense) async {
    final id = await _db.insert('expenses', expense.toMap());
    return expense.copyWith(id: id);
  }

  Future<void> update(Expense expense) => _db.update(
        'expenses',
        expense.copyWith(updatedAt: DateTime.now()).toMap(),
        where: 'id = ?',
        whereArgs: [expense.id],
      );

  Future<void> delete(int id) =>
      _db.delete('expenses', where: 'id = ?', whereArgs: [id]);

  /// Total spent between two instants, for a period summary.
  Future<int> totalBetween(DateTime from, DateTime to) async {
    final value = Sqflite.firstIntValue(
      await _db.rawQuery(
        'SELECT COALESCE(SUM(amount_minor), 0) FROM expenses '
        'WHERE occurred_at >= ? AND occurred_at < ?',
        [from.millisecondsSinceEpoch, to.millisecondsSinceEpoch],
      ),
    );
    return value ?? 0;
  }

  /// Business and personal totals per local calendar month, newest first.
  ///
  /// Grouped in Dart rather than SQL because "which month is this" is a
  /// local-timezone question, and SQLite would answer it in UTC.
  Future<List<MonthKindTotals>> kindTotalsByMonth({int months = 12}) async {
    final now = DateTime.now();
    final from = DateTime(now.year, now.month - (months - 1));
    final rows = await _db.query(
      'expenses',
      columns: ['occurred_at', 'amount_minor', 'is_business'],
      where: 'occurred_at >= ?',
      whereArgs: [from.millisecondsSinceEpoch],
    );

    final totals = <DateTime, MonthKindTotals>{};
    for (final row in rows) {
      final local =
          DateTime.fromMillisecondsSinceEpoch(row['occurred_at']! as int)
              .toLocal();
      final key = DateTime(local.year, local.month);
      final amount = row['amount_minor']! as int;
      final business = (row['is_business'] as int? ?? 0) == 1;
      final current = totals[key] ??
          MonthKindTotals(month: key, businessMinor: 0, personalMinor: 0);
      totals[key] = MonthKindTotals(
        month: key,
        businessMinor: current.businessMinor + (business ? amount : 0),
        personalMinor: current.personalMinor + (business ? 0 : amount),
      );
    }

    final ordered = totals.keys.toList()..sort((a, b) => b.compareTo(a));
    return [for (final key in ordered) totals[key]!];
  }

  /// Merchant names already seen, for autocomplete on the merchant field.
  Future<List<String>> merchantSuggestions(String query,
      {int limit = 6}) async {
    final key = normalizeName(query);
    final rows = await _db.rawQuery(
      '''
      SELECT merchant, COUNT(*) AS uses, MAX(occurred_at) AS latest
      FROM expenses
      WHERE merchant IS NOT NULL AND merchant <> ''
        AND LOWER(merchant) LIKE ? ESCAPE '\\'
      GROUP BY LOWER(merchant)
      ORDER BY uses DESC, latest DESC
      LIMIT ?
      ''',
      ['%${escapeLike(key)}%', limit],
    );
    return rows.map((r) => r['merchant']! as String).toList();
  }

  // ------------------------------------------------- merchant → category

  /// The category most often used for this merchant, or null if it's new.
  ///
  /// This is what turns the common case into "snap, confirm the amount, save"
  /// — the same usage-ranking idea that makes the grocery autocomplete useful
  /// from the second shop onward.
  Future<int?> predictCategory(String merchant) async {
    final key = normalizeName(merchant);
    if (key.isEmpty) return null;

    final rows = await _db.query(
      'merchant_categories',
      columns: ['category_id'],
      where: 'merchant_normalized = ?',
      whereArgs: [key],
      orderBy: 'uses DESC, last_used_at DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['category_id'] as int?;
  }

  /// Records that this merchant was filed under this category.
  Future<void> learnCategory(String merchant, int categoryId) async {
    final key = normalizeName(merchant);
    if (key.isEmpty) return;

    // Upsert: bump the count if the pair is known, otherwise start it at one.
    await _db.rawInsert(
      '''
      INSERT INTO merchant_categories
        (merchant_normalized, category_id, uses, last_used_at)
      VALUES (?, ?, 1, ?)
      ON CONFLICT(merchant_normalized, category_id) DO UPDATE SET
        uses = uses + 1,
        last_used_at = excluded.last_used_at
      ''',
      [key, categoryId, DateTime.now().millisecondsSinceEpoch],
    );
  }
}
