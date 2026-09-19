import 'package:sqflite/sqflite.dart';

import 'package:shopping_list/apps/calendar/data/models/occurrence_override.dart';

class OverrideDao {
  OverrideDao(this._db);

  final DatabaseExecutor _db;

  Future<List<OccurrenceOverride>> all() async {
    final rows = await _db.query('calendar_overrides');
    return rows.map(OccurrenceOverride.fromMap).toList();
  }

  Future<List<OccurrenceOverride>> forSeries(int seriesId) async {
    final rows = await _db.query(
      'calendar_overrides',
      where: 'series_id = ?',
      whereArgs: [seriesId],
    );
    return rows.map(OccurrenceOverride.fromMap).toList();
  }

  Future<void> upsert(OccurrenceOverride override) => _db.insert(
        'calendar_overrides',
        override.toMap()..remove('id'),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  Future<void> deleteFor({
    required int seriesId,
    required DateTime originalStart,
  }) =>
      _db.delete(
        'calendar_overrides',
        where: 'series_id = ? AND original_start = ?',
        whereArgs: [seriesId, originalStart.millisecondsSinceEpoch],
      );
}
