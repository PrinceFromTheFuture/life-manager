import 'package:sqflite/sqflite.dart';

import 'package:shopping_list/apps/gym/data/dao/exercise_dao.dart';
import 'package:shopping_list/apps/gym/data/dao/set_dao.dart';
import 'package:shopping_list/apps/gym/data/gym_activity.dart';
import 'package:shopping_list/apps/gym/data/models/exercise.dart';
import 'package:shopping_list/apps/gym/data/models/gym_set.dart';
import 'package:shopping_list/apps/gym/data/models/progress.dart';
import 'package:shopping_list/core/activity/activity_dao.dart';
import 'package:shopping_list/core/activity/activity_entry.dart';
import 'package:shopping_list/core/db/database.dart';
import 'package:shopping_list/core/util/load.dart';

/// Gym's public surface. Screens talk to this, never to the DAOs.
class GymRepository {
  GymRepository(this._db);

  final AppDatabase _db;

  ExerciseDao get _exercises => ExerciseDao(_db.db);
  SetDao get _sets => SetDao(_db.db);

  Future<List<Exercise>> exercises() => _exercises.all();

  Future<List<Exercise>> rack() => _exercises.onRack();

  Future<Exercise?> exercise(int id) => _exercises.byId(id);

  Future<Exercise> addExercise(String name) => _exercises.add(name);

  Future<void> renameExercise(int id, String name) =>
      _exercises.rename(id, name);

  Future<void> setOnRack(int id, bool onRack) =>
      _exercises.setOnRack(id, onRack);

  Future<void> reorderExercises(List<int> idsInOrder) =>
      _exercises.reorder(idsInOrder);

  Future<int> exerciseUsage(int id) => _exercises.usage(id);

  Future<void> deleteExercise(int id) async {
    await _db.db.transaction((txn) async {
      final sets = SetDao(txn);
      // Collect the days this exercise appeared on so their feed rows can
      // be rewritten after the cascade deletes the sets.
      final rows = await txn.query(
        'gym_sets',
        columns: ['occurred_at'],
        where: 'exercise_id = ?',
        whereArgs: [id],
      );
      final days = {
        for (final row in rows)
          GymActivity.startOfDay(
            DateTime.fromMillisecondsSinceEpoch(row['occurred_at']! as int),
          ),
      };
      await ExerciseDao(txn).delete(id);
      for (final day in days) {
        await _syncDayActivity(txn, sets, day);
      }
    });
  }

  Future<List<GymSet>> setsOnDay(DateTime day) => _sets.onDay(day);

  Future<List<ExerciseBlock>> blocksOnDay(DateTime day) async {
    final sets = await _sets.onDay(day);
    final order = <int>[];
    final grouped = <int, List<GymSet>>{};
    final names = <int, String>{};
    for (final set in sets) {
      if (!grouped.containsKey(set.exerciseId)) {
        order.add(set.exerciseId);
        grouped[set.exerciseId] = [];
        names[set.exerciseId] = set.exerciseName ?? 'Exercise';
      }
      grouped[set.exerciseId]!.add(set);
    }
    return [
      for (final id in order)
        ExerciseBlock(
          exerciseId: id,
          name: names[id]!,
          sets: grouped[id]!,
        ),
    ];
  }

  Future<int> volumeOnDay(DateTime day) => _sets.volumeOnDay(day);

  Future<int> setsTodayFor(int exerciseId, DateTime day) =>
      _sets.setsTodayFor(exerciseId, day);

  /// Logs a set onto [day]'s pass and keeps the hub feed in the same
  /// transaction.
  Future<GymSet> logSet({
    required int exerciseId,
    required int reps,
    required int weightG,
    required DateTime day,
  }) {
    return _db.db.transaction((txn) async {
      final now = DateTime.now();
      final occurredAt = _stampOnDay(day, now);
      final exercises = ExerciseDao(txn);
      final sets = SetDao(txn);

      final saved = await sets.insert(
        GymSet(
          exerciseId: exerciseId,
          occurredAt: occurredAt,
          reps: reps,
          weightG: weightG,
          createdAt: now,
        ),
      );
      await exercises.rememberLast(
        id: exerciseId,
        weightG: weightG,
        reps: reps,
      );
      await _syncDayActivity(txn, sets, day);
      return saved;
    });
  }

  Future<void> deleteSet(int id) async {
    await _db.db.transaction((txn) async {
      final sets = SetDao(txn);
      final existing = await sets.byId(id);
      if (existing == null) return;
      await sets.delete(id);
      await _syncDayActivity(txn, sets, existing.occurredAt);
    });
  }

  Future<WeekSummary> weekSummary([DateTime? around]) =>
      _sets.weekSummary(GymActivity.startOfWeek(around ?? DateTime.now()));

  Future<List<WorkoutMark>> workoutMarks(int exerciseId) =>
      _sets.workoutMarks(exerciseId);

  Future<List<ExerciseProgress>> progress([DateTime? around]) async {
    final weekStart = GymActivity.startOfWeek(around ?? DateTime.now());
    final rows = await _sets.progressRows(weekStart);
    final marksByExercise = await _sets.workoutMarksByExercise();
    final result = <ExerciseProgress>[];
    for (final row in rows) {
      final exercise = Exercise(
        id: row['id'] as int?,
        name: row['name']! as String,
        onRack: (row['on_rack'] as int? ?? 1) == 1,
        lastWeightG: row['last_weight_g'] as int?,
        lastReps: row['last_reps'] as int?,
        sort: row['sort']! as int,
      );
      final lastAtMs = row['last_set_at'] as int?;
      final all = marksByExercise[exercise.id!] ?? const <WorkoutMark>[];
      result.add(
        ExerciseProgress(
          exercise: exercise,
          lastWeightG: row['last_set_weight'] as int?,
          lastReps: row['last_set_reps'] as int?,
          lastAt: lastAtMs == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(lastAtMs),
          bestWeightG: row['best_weight'] as int?,
          bestReps: row['best_reps'] as int?,
          weekVolumeGramReps: (row['week_volume'] as num).toInt(),
          weekSets: (row['week_sets'] as num).toInt(),
          recentWorkouts: all.length <= 12 ? all : all.sublist(all.length - 12),
          workoutCount: all.length,
        ),
      );
    }
    return result;
  }

  /// Rewrites the one feed row that stands for this day's pass.
  Future<void> _syncDayActivity(
    DatabaseExecutor txn,
    SetDao sets,
    DateTime day,
  ) async {
    final writer = ActivityWriter(txn);
    final key = GymActivity.dayKey(day);
    await writer.deleteFor(
      appId: GymActivity.appId,
      refTable: GymActivity.daysRef,
      refId: key,
    );

    final count = await sets.countOnDay(day);
    if (count == 0) return;

    final names = await sets.exerciseNamesOnDay(day);
    final volume = await sets.volumeOnDay(day);
    final named = names.take(3).join(', ');
    final extra = names.length > 3 ? ' +${names.length - 3}' : '';
    final setWord = count == 1 ? 'set' : 'sets';

    await writer.write(
      ActivityEntry(
        appId: GymActivity.appId,
        kind: GymActivity.dayPass,
        title: 'Gym',
        subtitle: '$count $setWord · ${Load.formatVolume(volume)}'
            '${named.isEmpty ? '' : ' · $named$extra'}',
        occurredAt: GymActivity.startOfDay(day).add(
          const Duration(hours: 12),
        ),
        refTable: GymActivity.daysRef,
        refId: key,
      ),
    );
  }

  /// A set logged while looking at today uses the real clock. A set added to
  /// an earlier pass lands at noon on that day so it stays on the right date
  /// without pretending it happened "now".
  static DateTime _stampOnDay(DateTime day, DateTime now) {
    final target = GymActivity.startOfDay(day);
    final today = GymActivity.startOfDay(now);
    if (target == today) return now;
    return target.add(const Duration(hours: 12));
  }
}
