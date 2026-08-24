import 'package:sqflite/sqflite.dart';

import 'package:shopping_list/apps/tasks/data/models/task_item.dart';

class TaskDao {
  TaskDao(this._db);

  final DatabaseExecutor _db;

  Future<TaskItem?> byId(int id) async {
    final rows = await _db.query(
      'tasks_items',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : TaskItem.fromMap(rows.first);
  }

  Future<List<TaskItem>> openInProject(int projectId) async {
    final rows = await _db.query(
      'tasks_items',
      where: 'project_id = ? AND completed_at IS NULL',
      whereArgs: [projectId],
      orderBy: 'due_at IS NULL, due_at ASC, id ASC',
    );
    return rows.map(TaskItem.fromMap).toList();
  }

  Future<List<TaskItem>> doneInProject(int projectId) async {
    final rows = await _db.query(
      'tasks_items',
      where: 'project_id = ? AND completed_at IS NOT NULL',
      whereArgs: [projectId],
      orderBy: 'completed_at DESC',
    );
    return rows.map(TaskItem.fromMap).toList();
  }

  /// Open, unsnoozed items across living projects — the whole tray.
  Future<List<TaskItem>> trayCandidates(DateTime now) async {
    final snoozeCutoff = now.millisecondsSinceEpoch;
    final rows = await _db.rawQuery(
      '''
      SELECT i.* FROM tasks_items i
      INNER JOIN tasks_projects p ON p.id = i.project_id
      WHERE i.completed_at IS NULL
        AND p.archived_at IS NULL
        AND (i.snoozed_until IS NULL OR i.snoozed_until <= ?)
      ''',
      [snoozeCutoff],
    );
    return rows.map(TaskItem.fromMap).toList();
  }

  /// Open items that still want a local notification.
  Future<List<TaskItem>> pendingAlerts(DateTime now) async {
    final rows = await _db.rawQuery(
      '''
      SELECT i.* FROM tasks_items i
      INNER JOIN tasks_projects p ON p.id = i.project_id
      WHERE i.completed_at IS NULL
        AND p.archived_at IS NULL
        AND (
          i.snoozed_until > ?
          OR (i.due_at IS NOT NULL AND i.due_at > ?)
        )
      ''',
      [now.millisecondsSinceEpoch, now.millisecondsSinceEpoch],
    );
    return rows.map(TaskItem.fromMap).toList();
  }

  Future<TaskItem> insert(TaskItem item) async {
    final id = await _db.insert('tasks_items', item.toMap());
    return item.copyWith(id: id);
  }

  Future<void> update(TaskItem item) => _db.update(
        'tasks_items',
        item.toMap(),
        where: 'id = ?',
        whereArgs: [item.id],
      );

  Future<void> delete(int id) =>
      _db.delete('tasks_items', where: 'id = ?', whereArgs: [id]);
}
