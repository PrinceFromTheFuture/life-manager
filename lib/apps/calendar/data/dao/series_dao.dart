import 'package:sqflite/sqflite.dart';

import 'package:shopping_list/apps/calendar/data/models/series.dart';

class SeriesDao {
  SeriesDao(this._db);

  final DatabaseExecutor _db;

  Future<List<Series>> all() async {
    final rows = await _db.query(
      'calendar_series',
      orderBy: 'title COLLATE NOCASE ASC',
    );
    return rows.map(Series.fromMap).toList();
  }

  Future<List<Series>> active() async {
    final rows = await _db.query(
      'calendar_series',
      where: 'active = 1',
      orderBy: 'title COLLATE NOCASE ASC',
    );
    return rows.map(Series.fromMap).toList();
  }

  Future<Series?> byId(int id) async {
    final rows = await _db.query(
      'calendar_series',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : Series.fromMap(rows.first);
  }

  Future<Series> insert(Series series) async {
    final id = await _db.insert('calendar_series', series.toMap());
    return series.copyWith(id: id);
  }

  Future<void> update(Series series) => _db.update(
        'calendar_series',
        series.toMap(),
        where: 'id = ?',
        whereArgs: [series.id],
      );

  Future<void> delete(int id) => _db.delete(
        'calendar_series',
        where: 'id = ?',
        whereArgs: [id],
      );
}
