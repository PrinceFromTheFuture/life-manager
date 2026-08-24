import 'package:sqflite/sqflite.dart';

import 'package:shopping_list/apps/receipts/data/models/account_view.dart';

/// Named groups of accounts, and which one the Accounts page is on.
class AccountViewDao {
  AccountViewDao(this._db);

  final Database _db;

  Future<List<AccountView>> all() async {
    final rows = await _db.query('account_views', orderBy: 'sort ASC, id ASC');
    final members = await _db.query('account_view_members');
    final byView = <int, List<int>>{};
    for (final row in members) {
      byView
          .putIfAbsent(row['view_id']! as int, () => [])
          .add(row['account_id']! as int);
    }
    return [
      for (final row in rows)
        AccountView(
          id: row['id']! as int,
          name: row['name']! as String,
          sort: row['sort']! as int,
          accountIds: byView[row['id']! as int] ?? const [],
        ),
    ];
  }

  Future<int?> activeId() async {
    final rows = await _db.query('account_view_state', limit: 1);
    if (rows.isEmpty) return null;
    return rows.first['active_view_id'] as int?;
  }

  /// [id] null means All — every live account, no group.
  Future<void> setActive(int? id) => _db.insert(
        'account_view_state',
        {'id': 1, 'active_view_id': id},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  Future<AccountView> save(AccountView view) async {
    final name = view.name.trim();
    final ids = [
      for (final id in view.accountIds.toSet()) id,
    ]..sort();

    return _db.transaction((txn) async {
      late final int viewId;
      if (view.id == null) {
        final next = Sqflite.firstIntValue(
              await txn.rawQuery(
                'SELECT COALESCE(MAX(sort), -1) + 1 FROM account_views',
              ),
            ) ??
            0;
        viewId = await txn.insert('account_views', {
          'name': name,
          'sort': next,
        });
      } else {
        viewId = view.id!;
        await txn.update(
          'account_views',
          {'name': name},
          where: 'id = ?',
          whereArgs: [viewId],
        );
        await txn.delete(
          'account_view_members',
          where: 'view_id = ?',
          whereArgs: [viewId],
        );
      }

      final insert = txn.batch();
      for (final accountId in ids) {
        insert.insert('account_view_members', {
          'view_id': viewId,
          'account_id': accountId,
        });
      }
      await insert.commit(noResult: true);

      return AccountView(
        id: viewId,
        name: name,
        sort: view.sort,
        accountIds: ids,
      );
    });
  }

  Future<void> delete(int id) =>
      _db.delete('account_views', where: 'id = ?', whereArgs: [id]);
}
