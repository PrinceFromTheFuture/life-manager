import 'package:sqflite/sqflite.dart';

import 'package:shopping_list/apps/groceries/data/models/trip.dart';

class TripDao {
  TripDao(this._db);

  final DatabaseExecutor _db;

  Future<Trip?> activeTrip() async {
    final rows = await _db.query(
      'trips',
      where: 'status = ?',
      whereArgs: [TripStatus.active.name],
      limit: 1,
    );
    return rows.isEmpty ? null : Trip.fromMap(rows.first);
  }

  /// Returns the open trip, starting one if there isn't a trip open.
  ///
  /// Trips are created lazily like this rather than eagerly on launch, so
  /// opening the app and closing it again doesn't litter history with empty
  /// shopping trips that never happened.
  Future<Trip> ensureActive() async {
    final existing = await activeTrip();
    if (existing != null) return existing;

    final trip = Trip.start();
    final id = await _db.insert('trips', trip.toMap());
    return trip.copyWith(id: id);
  }

  Future<Trip?> byId(int id) async {
    final rows =
        await _db.query('trips', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Trip.fromMap(rows.first);
  }

  /// Closes out a trip. [receiptPath] must already be relative to the app
  /// documents directory.
  Future<void> complete({
    required int tripId,
    required int totalMinor,
    String? receiptPath,
    String? note,
  }) async {
    await _db.update(
      'trips',
      {
        'status': TripStatus.completed.name,
        'completed_at': DateTime.now().millisecondsSinceEpoch,
        'total_minor': totalMinor,
        'receipt_path': receiptPath,
        'note': note,
      },
      where: 'id = ?',
      whereArgs: [tripId],
    );
  }

  Future<void> setReceiptPath(int tripId, String? path) => _db.update(
        'trips',
        {'receipt_path': path},
        where: 'id = ?',
        whereArgs: [tripId],
      );

  /// Past trips, newest first, with their item counts folded into the same
  /// query so scrolling history doesn't fire a follow-up per row.
  Future<List<TripSummary>> history({int limit = 100, int offset = 0}) async {
    final rows = await _db.rawQuery(
      '''
      SELECT t.*,
             COUNT(i.id)                                   AS item_count,
             COALESCE(SUM(i.is_picked), 0)                 AS picked_count
      FROM trips t
      LEFT JOIN trip_items i ON i.trip_id = t.id
      WHERE t.status = ?
      GROUP BY t.id
      ORDER BY t.completed_at DESC
      LIMIT ? OFFSET ?
      ''',
      [TripStatus.completed.name, limit, offset],
    );

    return rows
        .map(
          (r) => TripSummary(
            trip: Trip.fromMap(r),
            itemCount: (r['item_count']! as int),
            pickedCount: (r['picked_count']! as num).toInt(),
          ),
        )
        .toList();
  }

  /// Deletes a trip. `ON DELETE CASCADE` removes its items, provided
  /// `PRAGMA foreign_keys` is on — which [AppDatabase] sets per connection.
  Future<void> delete(int id) =>
      _db.delete('trips', where: 'id = ?', whereArgs: [id]);
}
