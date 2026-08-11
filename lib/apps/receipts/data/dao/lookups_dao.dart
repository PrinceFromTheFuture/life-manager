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
    final rows = await _db
        .query('accounts', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Account.fromMap(rows.first);
  }

  Future<Account> addAccount(String name, {String kind = 'other', String? last4}) async {
    final next = Sqflite.firstIntValue(
          await _db.rawQuery('SELECT COALESCE(MAX(sort), -1) + 1 FROM accounts'),
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
}
