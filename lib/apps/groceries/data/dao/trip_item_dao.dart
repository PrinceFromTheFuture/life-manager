import 'package:sqflite/sqflite.dart';

import 'package:shopping_list/apps/groceries/data/models/trip_item.dart';

class TripItemDao {
  TripItemDao(this._db);

  final DatabaseExecutor _db;

  Future<List<TripItem>> forTrip(int tripId) async {
    final rows = await _db.query(
      'trip_items',
      where: 'trip_id = ?',
      whereArgs: [tripId],
      orderBy: 'sort_order ASC, id ASC',
    );
    return rows.map(TripItem.fromMap).toList();
  }

  Future<TripItem> insert(TripItem item) async {
    final id = await _db.insert('trip_items', item.toMap());
    return item.copyWith(id: id);
  }

  /// Re-inserts an item keeping its original id, so undo restores the row the
  /// user deleted rather than a lookalike with a new identity.
  Future<void> restore(TripItem item) =>
      _db.insert('trip_items', item.toMap());

  /// Finds an unpicked line for the same product, so adding "Milk" twice bumps
  /// the quantity instead of stacking duplicate rows.
  Future<TripItem?> findUnpickedByProduct(int tripId, int productId) async {
    final rows = await _db.query(
      'trip_items',
      where: 'trip_id = ? AND product_id = ? AND is_picked = 0',
      whereArgs: [tripId, productId],
      limit: 1,
    );
    return rows.isEmpty ? null : TripItem.fromMap(rows.first);
  }

  Future<void> setPicked(int itemId, bool picked) async {
    if (!picked) {
      await _db.update(
        'trip_items',
        {'is_picked': 0, 'picked_at': null},
        where: 'id = ?',
        whereArgs: [itemId],
      );
      return;
    }

    final rows = await _db.query(
      'trip_items',
      columns: ['trip_id'],
      where: 'id = ?',
      whereArgs: [itemId],
      limit: 1,
    );
    if (rows.isEmpty) return;
    final tripId = rows.first['trip_id']! as int;
    final last = Sqflite.firstIntValue(
      await _db.rawQuery(
        'SELECT MAX(picked_at) FROM trip_items '
        'WHERE trip_id = ? AND is_picked = 1',
        [tripId],
      ),
    );
    final now = DateTime.now().millisecondsSinceEpoch;
    // Same-millisecond ticks would otherwise fall back to insert order,
    // which is the planning list — the opposite of a store walk.
    final at = last == null ? now : (now > last ? now : last + 1);

    await _db.update(
      'trip_items',
      {'is_picked': 1, 'picked_at': at},
      where: 'id = ?',
      whereArgs: [itemId],
    );
  }

  Future<void> setQuantity(int itemId, double quantity, {String? unit}) =>
      _db.update(
        'trip_items',
        {'quantity': quantity, 'unit': unit},
        where: 'id = ?',
        whereArgs: [itemId],
      );

  Future<void> delete(int itemId) =>
      _db.delete('trip_items', where: 'id = ?', whereArgs: [itemId]);

  Future<int> nextSortOrder(int tripId) async {
    final value = Sqflite.firstIntValue(
      await _db.rawQuery(
        'SELECT COALESCE(MAX(sort_order), -1) + 1 FROM trip_items '
        'WHERE trip_id = ?',
        [tripId],
      ),
    );
    return value ?? 0;
  }

  /// Clears every check on a trip — the "start over" path when the user
  /// realises they were checking off the wrong list.
  Future<void> unpickAll(int tripId) => _db.update(
        'trip_items',
        {'is_picked': 0, 'picked_at': null},
        where: 'trip_id = ?',
        whereArgs: [tripId],
      );

  /// Completed shops as pick walks, oldest first.
  ///
  /// Each inner list is the product ids in the order they were ticked on
  /// that trip. The planning list never sees this.
  Future<List<List<int>>> pickWalks() async {
    final rows = await _db.rawQuery(
      '''
      SELECT i.trip_id, i.product_id
      FROM trip_items i
      JOIN trips t ON t.id = i.trip_id
      WHERE t.status = 'completed'
        AND i.is_picked = 1
        AND i.product_id IS NOT NULL
        AND i.picked_at IS NOT NULL
      ORDER BY t.completed_at ASC, t.id ASC, i.picked_at ASC, i.id ASC
      ''',
    );

    final walks = <int, List<int>>{};
    final order = <int>[];
    for (final row in rows) {
      final tripId = row['trip_id']! as int;
      final productId = row['product_id']! as int;
      var walk = walks[tripId];
      if (walk == null) {
        walk = [];
        walks[tripId] = walk;
        order.add(tripId);
      }
      walk.add(productId);
    }
    return [for (final id in order) walks[id]!];
  }
}
