import 'package:sqflite/sqflite.dart';

import 'package:shopping_list/apps/tasks/data/models/project.dart';

class ProjectDao {
  ProjectDao(this._db);

  final DatabaseExecutor _db;

  Future<List<Project>> living() async {
    final rows = await _db.query(
      'tasks_projects',
      where: 'archived_at IS NULL',
      orderBy: 'sort ASC, name ASC',
    );
    return rows.map(Project.fromMap).toList();
  }

  Future<List<Project>> all() async {
    final rows = await _db.query(
      'tasks_projects',
      orderBy: 'sort ASC, name ASC',
    );
    return rows.map(Project.fromMap).toList();
  }

  Future<Project?> byId(int id) async {
    final rows = await _db.query(
      'tasks_projects',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : Project.fromMap(rows.first);
  }

  Future<Project> insert(Project project) async {
    final id = await _db.insert('tasks_projects', project.toMap());
    return project.copyWith(id: id);
  }

  Future<void> update(Project project) => _db.update(
        'tasks_projects',
        project.toMap(),
        where: 'id = ?',
        whereArgs: [project.id],
      );

  Future<int> nextSort() async =>
      (Sqflite.firstIntValue(
            await _db.rawQuery(
              'SELECT COALESCE(MAX(sort), -1) + 1 FROM tasks_projects',
            ),
          ) ??
          0);

  Future<List<String>> usedInkIds() async {
    final rows = await _db.query(
      'tasks_projects',
      columns: ['ink_id'],
      where: 'archived_at IS NULL',
    );
    return [for (final row in rows) row['ink_id']! as String];
  }

  Future<List<String>> usedIconIds() async {
    final rows = await _db.query(
      'tasks_projects',
      columns: ['icon_id'],
      where: 'archived_at IS NULL',
    );
    return [for (final row in rows) row['icon_id']! as String];
  }
}
