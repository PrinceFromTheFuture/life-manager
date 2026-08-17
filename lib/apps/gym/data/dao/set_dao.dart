import 'package:sqflite/sqflite.dart';

import 'package:shopping_list/apps/gym/data/gym_activity.dart';
import 'package:shopping_list/apps/gym/data/models/gym_set.dart';
import 'package:shopping_list/apps/gym/data/models/progress.dart';

class SetDao {
  SetDao(this._db);

  final DatabaseExecutor _db;

  Future<List<GymSet>> onDay(DateTime day) async {
    final from = GymActivity.startOfDay(day);
    final to = GymActivity.startOfNextDay(day);
    final rows = await _db.rawQuery(
      '''
      SELECT s.*, e.name AS exercise_name
      FROM gym_sets s
      JOIN gym_exercises e ON e.id = s.exercise_id
      WHERE s.occurred_at >= ? AND s.occurred_at < ?
      ORDER BY s.created_at ASC, s.id ASC
      ''',
      [from.millisecondsSinceEpoch, to.millisecondsSinceEpoch],
    );
    return rows.map(GymSet.fromMap).toList();
  }

  Future<GymSet> insert(GymSet set) async {
    final id = await _db.insert('gym_sets', set.toMap());
    return GymSet(
      id: id,
      exerciseId: set.exerciseId,
      occurredAt: set.occurredAt,
      reps: set.reps,
      weightG: set.weightG,
      createdAt: set.createdAt,
    );
  }

  Future<void> delete(int id) =>
      _db.delete('gym_sets', where: 'id = ?', whereArgs: [id]);

  Future<GymSet?> byId(int id) async {
    final rows = await _db.rawQuery(
      '''
      SELECT s.*, e.name AS exercise_name
      FROM gym_sets s
      JOIN gym_exercises e ON e.id = s.exercise_id
      WHERE s.id = ?
      LIMIT 1
      ''',
      [id],
    );
    return rows.isEmpty ? null : GymSet.fromMap(rows.first);
  }

  Future<int> countOnDay(DateTime day) async {
    final from = GymActivity.startOfDay(day);
    final to = GymActivity.startOfNextDay(day);
    return Sqflite.firstIntValue(
          await _db.rawQuery(
            'SELECT COUNT(*) FROM gym_sets '
            'WHERE occurred_at >= ? AND occurred_at < ?',
            [from.millisecondsSinceEpoch, to.millisecondsSinceEpoch],
          ),
        ) ??
        0;
  }

  Future<int> volumeOnDay(DateTime day) async {
    final from = GymActivity.startOfDay(day);
    final to = GymActivity.startOfNextDay(day);
    return Sqflite.firstIntValue(
          await _db.rawQuery(
            'SELECT COALESCE(SUM(weight_g * reps), 0) FROM gym_sets '
            'WHERE occurred_at >= ? AND occurred_at < ?',
            [from.millisecondsSinceEpoch, to.millisecondsSinceEpoch],
          ),
        ) ??
        0;
  }

  /// Distinct exercise names on a day, in the order they first appeared.
  Future<List<String>> exerciseNamesOnDay(DateTime day) async {
    final from = GymActivity.startOfDay(day);
    final to = GymActivity.startOfNextDay(day);
    final rows = await _db.rawQuery(
      '''
      SELECT e.name
      FROM gym_sets s
      JOIN gym_exercises e ON e.id = s.exercise_id
      WHERE s.occurred_at >= ? AND s.occurred_at < ?
      GROUP BY e.id
      ORDER BY MIN(s.created_at) ASC
      ''',
      [from.millisecondsSinceEpoch, to.millisecondsSinceEpoch],
    );
    return [for (final row in rows) row['name']! as String];
  }

  Future<int> setsTodayFor(int exerciseId, DateTime day) async {
    final from = GymActivity.startOfDay(day);
    final to = GymActivity.startOfNextDay(day);
    return Sqflite.firstIntValue(
          await _db.rawQuery(
            'SELECT COUNT(*) FROM gym_sets '
            'WHERE exercise_id = ? AND occurred_at >= ? AND occurred_at < ?',
            [
              exerciseId,
              from.millisecondsSinceEpoch,
              to.millisecondsSinceEpoch,
            ],
          ),
        ) ??
        0;
  }

  Future<WeekSummary> weekSummary(DateTime weekStart) async {
    final from = GymActivity.startOfDay(weekStart);
    final to = from.add(const Duration(days: 7));
    final row = (await _db.rawQuery(
      '''
      SELECT
        COUNT(*) AS sets,
        COALESCE(SUM(weight_g * reps), 0) AS volume
      FROM gym_sets
      WHERE occurred_at >= ? AND occurred_at < ?
      ''',
      [from.millisecondsSinceEpoch, to.millisecondsSinceEpoch],
    ))
        .first;

    // Distinct UTC days can split a local evening across two buckets.
    // Count local calendar days in Dart instead.
    final dayRows = await _db.query(
      'gym_sets',
      columns: ['occurred_at'],
      where: 'occurred_at >= ? AND occurred_at < ?',
      whereArgs: [from.millisecondsSinceEpoch, to.millisecondsSinceEpoch],
    );
    final days = <int>{};
    for (final r in dayRows) {
      days.add(GymActivity.dayKey(
        DateTime.fromMillisecondsSinceEpoch(r['occurred_at']! as int),
      ));
    }

    return WeekSummary(
      daysTrained: days.length,
      sets: row['sets']! as int,
      volumeGramReps: (row['volume'] as num).toInt(),
    );
  }

  Future<List<Map<String, Object?>>> progressRows(DateTime weekStart) async {
    final from = GymActivity.startOfDay(weekStart);
    final to = from.add(const Duration(days: 7));
    return _db.rawQuery(
      '''
      SELECT
        e.id,
        e.name,
        e.on_rack,
        e.last_weight_g,
        e.last_reps,
        e.sort,
        (SELECT s.weight_g FROM gym_sets s
          WHERE s.exercise_id = e.id
          ORDER BY s.occurred_at DESC, s.id DESC LIMIT 1) AS last_set_weight,
        (SELECT s.reps FROM gym_sets s
          WHERE s.exercise_id = e.id
          ORDER BY s.occurred_at DESC, s.id DESC LIMIT 1) AS last_set_reps,
        (SELECT s.occurred_at FROM gym_sets s
          WHERE s.exercise_id = e.id
          ORDER BY s.occurred_at DESC, s.id DESC LIMIT 1) AS last_set_at,
        (SELECT MAX(s.weight_g) FROM gym_sets s
          WHERE s.exercise_id = e.id) AS best_weight,
        (SELECT MAX(s.reps) FROM gym_sets s
          WHERE s.exercise_id = e.id) AS best_reps,
        (SELECT COALESCE(SUM(s.weight_g * s.reps), 0) FROM gym_sets s
          WHERE s.exercise_id = e.id
            AND s.occurred_at >= ? AND s.occurred_at < ?) AS week_volume,
        (SELECT COUNT(*) FROM gym_sets s
          WHERE s.exercise_id = e.id
            AND s.occurred_at >= ? AND s.occurred_at < ?) AS week_sets
      FROM gym_exercises e
      WHERE EXISTS (SELECT 1 FROM gym_sets s WHERE s.exercise_id = e.id)
      ORDER BY e.sort ASC, e.name ASC
      ''',
      [
        from.millisecondsSinceEpoch,
        to.millisecondsSinceEpoch,
        from.millisecondsSinceEpoch,
        to.millisecondsSinceEpoch,
      ],
    );
  }

  /// Heaviest set per local calendar day for [exerciseId], oldest first, last
  /// [limit] sessions. Grouped in Dart so an evening session is not split
  /// across UTC midnight.
  Future<List<int>> recentTopWeights(int exerciseId, {int limit = 8}) async {
    final rows = await _db.query(
      'gym_sets',
      columns: ['occurred_at', 'weight_g'],
      where: 'exercise_id = ?',
      whereArgs: [exerciseId],
      orderBy: 'occurred_at ASC, id ASC',
    );
    final byDay = <int, int>{};
    final order = <int>[];
    for (final row in rows) {
      final key = GymActivity.dayKey(
        DateTime.fromMillisecondsSinceEpoch(row['occurred_at']! as int),
      );
      final weight = row['weight_g']! as int;
      if (!byDay.containsKey(key)) order.add(key);
      final prev = byDay[key];
      if (prev == null || weight > prev) byDay[key] = weight;
    }
    final all = [for (final key in order) byDay[key]!];
    if (all.length <= limit) return all;
    return all.sublist(all.length - limit);
  }
}
