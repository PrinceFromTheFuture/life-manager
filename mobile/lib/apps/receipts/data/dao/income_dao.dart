import 'package:sqflite/sqflite.dart';

import 'package:shopping_list/apps/receipts/data/models/income.dart';
import 'package:shopping_list/core/util/normalize.dart';

class IncomeDao {
  IncomeDao(this._db);

  final DatabaseExecutor _db;

  Future<List<Income>> recent({int limit = 60}) async {
    final rows = await _db.query(
      'incomes',
      orderBy: 'occurred_at DESC, id DESC',
      limit: limit,
    );
    return rows.map(Income.fromMap).toList();
  }

  Future<List<Income>> between(DateTime from, DateTime to) async {
    final rows = await _db.query(
      'incomes',
      where: 'occurred_at >= ? AND occurred_at < ?',
      whereArgs: [from.millisecondsSinceEpoch, to.millisecondsSinceEpoch],
      orderBy: 'occurred_at DESC, id DESC',
    );
    return rows.map(Income.fromMap).toList();
  }

  Future<Income?> byId(int id) async {
    final rows =
        await _db.query('incomes', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Income.fromMap(rows.first);
  }

  Future<Income> insert(Income income) async {
    final id = await _db.insert('incomes', income.toMap());
    return income.copyWith(id: id);
  }

  Future<void> update(Income income) => _db.update(
        'incomes',
        income.toMap(),
        where: 'id = ?',
        whereArgs: [income.id],
      );

  Future<void> delete(int id) =>
      _db.delete('incomes', where: 'id = ?', whereArgs: [id]);

  /// Sources already used, so "Salary" is one tap the second month.
  Future<List<String>> sourceSuggestions(String query, {int limit = 6}) async {
    final key = normalizeName(query);
    final rows = await _db.rawQuery(
      '''
      SELECT source_name, COUNT(*) AS uses, MAX(occurred_at) AS latest
      FROM incomes
      WHERE source_name <> '' AND LOWER(source_name) LIKE ? ESCAPE '\\'
      GROUP BY LOWER(source_name)
      ORDER BY uses DESC, latest DESC
      LIMIT ?
      ''',
      ['%${escapeLike(key)}%', limit],
    );
    return rows.map((r) => r['source_name']! as String).toList();
  }

  Future<int> totalBetween(DateTime from, DateTime to) async =>
      Sqflite.firstIntValue(
        await _db.rawQuery(
          'SELECT COALESCE(SUM(amount_minor), 0) FROM incomes '
          'WHERE occurred_at >= ? AND occurred_at < ?',
          [from.millisecondsSinceEpoch, to.millisecondsSinceEpoch],
        ),
      ) ??
      0;
}
