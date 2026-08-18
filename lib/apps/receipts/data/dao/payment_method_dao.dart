import 'package:sqflite/sqflite.dart';

import 'package:shopping_list/apps/receipts/data/models/payment_method.dart';

class PaymentMethodDao {
  PaymentMethodDao(this._db);

  final DatabaseExecutor _db;

  Future<List<PaymentMethod>> all({bool includeArchived = false}) async {
    final rows = await _db.query(
      'payment_methods',
      where: includeArchived ? null : 'archived_at IS NULL',
      orderBy: 'sort ASC, id ASC',
    );
    return rows.map(PaymentMethod.fromMap).toList();
  }

  Future<List<PaymentMethod>> forAccount(int accountId) async {
    final rows = await _db.query(
      'payment_methods',
      where: 'account_id = ? AND archived_at IS NULL',
      whereArgs: [accountId],
      orderBy: 'sort ASC, id ASC',
    );
    return rows.map(PaymentMethod.fromMap).toList();
  }

  Future<PaymentMethod?> byId(int id) async {
    final rows = await _db.query(
      'payment_methods',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : PaymentMethod.fromMap(rows.first);
  }

  Future<PaymentMethod> insert(PaymentMethod method) async {
    final next = Sqflite.firstIntValue(
          await _db.rawQuery(
            'SELECT COALESCE(MAX(sort), -1) + 1 FROM payment_methods',
          ),
        ) ??
        0;
    final withSort = method.copyWith(sort: next);
    final id = await _db.insert('payment_methods', withSort.toMap());
    return withSort.copyWith(id: id);
  }

  Future<void> update(PaymentMethod method) => _db.update(
        'payment_methods',
        method.toMap(),
        where: 'id = ?',
        whereArgs: [method.id],
      );

  /// Archives rather than deletes. Expenses point at this row, and a slip that
  /// forgets what paid for it is worse than a card you can no longer choose.
  Future<void> archive(int id) => _db.update(
        'payment_methods',
        {'archived_at': DateTime.now().millisecondsSinceEpoch},
        where: 'id = ?',
        whereArgs: [id],
      );

  Future<void> restore(int id) => _db.update(
        'payment_methods',
        {'archived_at': null},
        where: 'id = ?',
        whereArgs: [id],
      );

  Future<int> usage(int id) async =>
      Sqflite.firstIntValue(
        await _db.rawQuery(
          'SELECT COUNT(*) FROM expenses WHERE payment_method_id = ?',
          [id],
        ),
      ) ??
      0;

  /// The method on the most recent slip.
  ///
  /// This is what lets the expense sheet open with "paid with" already
  /// answered. Derived rather than stored as a setting, so there is no second
  /// copy of the truth to keep in step.
  Future<int?> lastUsedId() async {
    final rows = await _db.query(
      'expenses',
      columns: ['payment_method_id'],
      where: 'payment_method_id IS NOT NULL',
      orderBy: 'occurred_at DESC, id DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['payment_method_id'] as int?;
  }

  /// Method ids ordered by how often they are used, busiest first, so the rare
  /// correction is still one tap on the leftmost alternative.
  Future<List<int>> idsByUse() async {
    final rows = await _db.rawQuery(
      '''
      SELECT payment_method_id AS id, COUNT(*) AS uses, MAX(occurred_at) AS latest
      FROM expenses
      WHERE payment_method_id IS NOT NULL
      GROUP BY payment_method_id
      ORDER BY uses DESC, latest DESC
      ''',
    );
    return [for (final row in rows) row['id']! as int];
  }

  /// The oldest charge on a method, which is where the settlement sweep starts
  /// looking when nothing has ever been settled. Null when the card has never
  /// been used, in which case there is nothing to settle.
  Future<DateTime?> firstChargeAt(int paymentMethodId) async {
    final rows = await _db.query(
      'expenses',
      columns: ['occurred_at'],
      where: 'payment_method_id = ?',
      whereArgs: [paymentMethodId],
      orderBy: 'occurred_at ASC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return DateTime.fromMillisecondsSinceEpoch(rows.first['occurred_at']! as int);
  }

  /// Everything charged to a credit method inside a window and not yet
  /// settled, for the cycle band.
  Future<int> chargedBetween(
    int paymentMethodId,
    DateTime from,
    DateTime to,
  ) async {
    final value = Sqflite.firstIntValue(
      await _db.rawQuery(
        'SELECT COALESCE(SUM(amount_minor), 0) FROM expenses '
        'WHERE payment_method_id = ? AND occurred_at >= ? AND occurred_at < ?',
        [
          paymentMethodId,
          from.millisecondsSinceEpoch,
          to.millisecondsSinceEpoch,
        ],
      ),
    );
    return value ?? 0;
  }
}
