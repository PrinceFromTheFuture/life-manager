import 'package:sqflite/sqflite.dart';

import 'package:shopping_list/apps/gym/data/models/exercise.dart';
import 'package:shopping_list/core/util/normalize.dart';

class ExerciseDao {
  ExerciseDao(this._db);

  final DatabaseExecutor _db;

  Future<List<Exercise>> all() async {
    final rows =
        await _db.query('gym_exercises', orderBy: 'sort ASC, name ASC');
    return rows.map(Exercise.fromMap).toList();
  }

  Future<List<Exercise>> onRack() async {
    final rows = await _db.query(
      'gym_exercises',
      where: 'on_rack = 1',
      orderBy: 'sort ASC, name ASC',
    );
    return rows.map(Exercise.fromMap).toList();
  }

  Future<Exercise?> byId(int id) async {
    final rows = await _db.query(
      'gym_exercises',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : Exercise.fromMap(rows.first);
  }

  Future<Exercise> add(String name) async {
    final next = Sqflite.firstIntValue(
          await _db.rawQuery(
            'SELECT COALESCE(MAX(sort), -1) + 1 FROM gym_exercises',
          ),
        ) ??
        0;
    final exercise = Exercise(name: cleanName(name), onRack: true, sort: next);
    final id = await _db.insert(
      'gym_exercises',
      exercise.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    return id == 0
        ? (await all()).firstWhere((e) => e.name == exercise.name)
        : exercise.copyWith(id: id);
  }

  Future<void> rename(int id, String name) => _db.update(
        'gym_exercises',
        {'name': cleanName(name)},
        where: 'id = ?',
        whereArgs: [id],
      );

  Future<void> setOnRack(int id, bool onRack) => _db.update(
        'gym_exercises',
        {'on_rack': onRack ? 1 : 0},
        where: 'id = ?',
        whereArgs: [id],
      );

  Future<void> rememberLast({
    required int id,
    required int weightG,
    required int reps,
  }) =>
      _db.update(
        'gym_exercises',
        {'last_weight_g': weightG, 'last_reps': reps},
        where: 'id = ?',
        whereArgs: [id],
      );

  Future<void> delete(int id) =>
      _db.delete('gym_exercises', where: 'id = ?', whereArgs: [id]);

  Future<int> usage(int id) async =>
      Sqflite.firstIntValue(
        await _db.rawQuery(
          'SELECT COUNT(*) FROM gym_sets WHERE exercise_id = ?',
          [id],
        ),
      ) ??
      0;

  Future<void> reorder(List<int> idsInOrder) async {
    for (var i = 0; i < idsInOrder.length; i++) {
      await _db.update(
        'gym_exercises',
        {'sort': i},
        where: 'id = ?',
        whereArgs: [idsInOrder[i]],
      );
    }
  }
}
