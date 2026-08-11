import 'package:sqflite/sqflite.dart';

import '../models/trip_item.dart';

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

  Future<void> setPicked(int itemId, bool picked) => _db.update(
        'trip_items',
        {
          'is_picked': picked ? 1 : 0,
          'picked_at': picked ? DateTime.now().millisecondsSinceEpoch : null,
        },
        where: 'id = ?',
        whereArgs: [itemId],
      );

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
}
