import 'package:sqflite/sqflite.dart';

import 'package:shopping_list/apps/receipts/data/models/account.dart';
import 'package:shopping_list/apps/receipts/data/models/expense_category.dart';

/// Categories and accounts — the two short, user-editable lists the entry form
/// offers as chips.
class LookupsDao {
  LookupsDao(this._db);

  final DatabaseExecutor _db;

  Future<List<ExpenseCategory>> categories() async {
    final rows =
        await _db.query('expense_categories', orderBy: 'sort ASC, name ASC');
    return rows.map(ExpenseCategory.fromMap).toList();
  }

  Future<ExpenseCategory?> categoryById(int id) async {
    final rows = await _db.query(
      'expense_categories',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : ExpenseCategory.fromMap(rows.first);
  }

  Future<ExpenseCategory> addCategory(String name) async {
    final next = Sqflite.firstIntValue(
          await _db.rawQuery(
            'SELECT COALESCE(MAX(sort), -1) + 1 FROM expense_categories',
          ),
        ) ??
        0;
    final category = ExpenseCategory(name: name.trim(), sort: next);
    final id = await _db.insert(
      'expense_categories',
      category.toMap(),
      // Adding a category that already exists should be a no-op, not a crash.
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    return id == 0
        ? (await categories()).firstWhere((c) => c.name == name.trim())
        : ExpenseCategory(id: id, name: category.name, sort: next);
  }

  Future<List<Account>> accounts() async {
    final rows = await _db.query('accounts', orderBy: 'sort ASC, name ASC');
    return rows.map(Account.fromMap).toList();
  }

  Future<Account?> accountById(int id) async {
    final rows =
        await _db.query('accounts', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Account.fromMap(rows.first);
  }

  Future<void> renameCategory(int id, String name) => _db.update(
        'expense_categories',
        {'name': name.trim()},
        where: 'id = ?',
        whereArgs: [id],
      );

  /// Removes a category. Expenses filed under it keep their record and simply
  /// lose the label — the schema's `ON DELETE SET NULL` makes deleting a
  /// category safe rather than destructive.
  Future<void> deleteCategory(int id) =>
      _db.delete('expense_categories', where: 'id = ?', whereArgs: [id]);

  /// How many expenses use this category, so the UI can say what deleting it
  /// will actually affect instead of asking blind.
  Future<int> categoryUsage(int id) async =>
      Sqflite.firstIntValue(
        await _db.rawQuery(
          'SELECT COUNT(*) FROM expenses WHERE category_id = ?',
          [id],
        ),
      ) ??
      0;

  Future<void> reorderCategories(List<int> idsInOrder) async {
    for (var i = 0; i < idsInOrder.length; i++) {
      await _db.update(
        'expense_categories',
        {'sort': i},
        where: 'id = ?',
        whereArgs: [idsInOrder[i]],
      );
    }
  }

  Future<Account> addAccount(String name,
      {String kind = 'other', String? last4}) async {
    final next = Sqflite.firstIntValue(
          await _db
              .rawQuery('SELECT COALESCE(MAX(sort), -1) + 1 FROM accounts'),
        ) ??
        0;
    final account =
        Account(name: name.trim(), kind: kind, last4: last4, sort: next);
    final id = await _db.insert(
      'accounts',
      account.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    return id == 0
        ? (await accounts()).firstWhere((a) => a.name == name.trim())
        : Account(
            id: id,
            name: account.name,
            kind: kind,
            last4: last4,
            sort: next,
          );
  }

  Future<void> renameAccount(int id, String name) => _db.update(
        'accounts',
        {'name': name.trim()},
        where: 'id = ?',
        whereArgs: [id],
      );

  Future<void> deleteAccount(int id) =>
      _db.delete('accounts', where: 'id = ?', whereArgs: [id]);

  Future<int> accountUsage(int id) async =>
      Sqflite.firstIntValue(
        await _db.rawQuery(
          'SELECT COUNT(*) FROM expenses WHERE account_id = ?',
          [id],
        ),
      ) ??
      0;

  Future<void> reorderAccounts(List<int> idsInOrder) async {
    for (var i = 0; i < idsInOrder.length; i++) {
      await _db.update(
        'accounts',
        {'sort': i},
        where: 'id = ?',
        whereArgs: [idsInOrder[i]],
      );
    }
  }
}
