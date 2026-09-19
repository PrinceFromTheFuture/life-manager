import 'package:sqflite/sqflite.dart';

import 'package:shopping_list/apps/calendar/data/models/place.dart';

class LocationDao {
  LocationDao(this._db);

  final DatabaseExecutor _db;

  Future<List<Place>> all() async {
    final rows = await _db.query(
      'calendar_locations',
      orderBy: 'title COLLATE NOCASE ASC',
    );
    return rows.map(Place.fromMap).toList();
  }

  Future<Place?> byId(int id) async {
    final rows = await _db.query(
      'calendar_locations',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : Place.fromMap(rows.first);
  }

  Future<List<String>> usedInkIds() async {
    final rows = await _db.query('calendar_locations', columns: ['ink_id']);
    return [for (final row in rows) row['ink_id']! as String];
  }

  Future<List<String>> usedIconIds() async {
    final rows = await _db.query('calendar_locations', columns: ['icon_id']);
    return [for (final row in rows) row['icon_id']! as String];
  }

  Future<Place> insert(Place place) async {
    final id = await _db.insert('calendar_locations', place.toMap());
    return place.copyWith(id: id);
  }

  Future<void> update(Place place) => _db.update(
        'calendar_locations',
        place.toMap(),
        where: 'id = ?',
        whereArgs: [place.id],
      );

  Future<void> delete(int id) => _db.delete(
        'calendar_locations',
        where: 'id = ?',
        whereArgs: [id],
      );
}
