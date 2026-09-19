import 'package:shopping_list/apps/tasks/data/dao/project_dao.dart';
import 'package:shopping_list/apps/tasks/data/dao/task_dao.dart';
import 'package:shopping_list/apps/tasks/data/models/project.dart';
import 'package:shopping_list/apps/tasks/data/models/project_mark.dart';
import 'package:shopping_list/apps/tasks/data/models/task_item.dart';
import 'package:shopping_list/apps/tasks/data/models/tray_entry.dart';
import 'package:shopping_list/apps/tasks/data/tasks_activity.dart';
import 'package:shopping_list/core/activity/activity_dao.dart';
import 'package:shopping_list/core/activity/activity_entry.dart';
import 'package:shopping_list/core/db/database.dart';
import 'package:shopping_list/core/design/stamp_ink.dart';
import 'package:shopping_list/core/util/normalize.dart';

/// Tasks' public surface. Screens talk to this, never to the DAOs.
class TasksRepository {
  TasksRepository(this._db);

  final AppDatabase _db;

  ProjectDao get _projects => ProjectDao(_db.db);
  TaskDao get _items => TaskDao(_db.db);

  Future<List<Project>> livingProjects() => _projects.living();

  Future<Project?> project(int id) => _projects.byId(id);

  Future<Project> addProject({
    required String name,
    String? inkId,
    String? iconId,
  }) {
    return _db.db.transaction((txn) async {
      final projects = ProjectDao(txn);
      final now = DateTime.now();
      final usedInk = await projects.usedInkIds();
      final usedIcons = await projects.usedIconIds();
      final project = await projects.insert(
        Project(
          name: cleanName(name),
          inkId: inkId ?? StampInk.next(usedInk),
          iconId: iconId ?? ProjectMark.next(usedIcons),
          sort: await projects.nextSort(),
          createdAt: now,
          updatedAt: now,
        ),
      );
      await ActivityWriter(txn).write(
        ActivityEntry(
          appId: TasksActivity.appId,
          kind: TasksActivity.projectAdded,
          title: project.name,
          subtitle: 'Project opened',
          occurredAt: now,
          refTable: TasksActivity.projectsTable,
          refId: project.id,
        ),
      );
      return project;
    });
  }

  Future<void> updateProject(Project project) =>
      _projects.update(project.copyWith(updatedAt: DateTime.now()));

  Future<void> archiveProject(int id) async {
    final existing = await _projects.byId(id);
    if (existing == null) return;
    await _projects.update(
      existing.copyWith(archivedAt: DateTime.now(), updatedAt: DateTime.now()),
    );
  }

  Future<List<TaskItem>> openTasks(int projectId) =>
      _items.openInProject(projectId);

  Future<List<TaskItem>> doneTasks(int projectId) =>
      _items.doneInProject(projectId);

  Future<TaskItem?> task(int id) => _items.byId(id);

  Future<List<TrayEntry>> tray({DateTime? now}) async {
    final at = now ?? DateTime.now();
    final items = await _items.trayCandidates(at);
    final projects = {
      for (final project in await _projects.living())
        if (project.id != null) project.id!: project,
    };
    final entries = <TrayEntry>[];
    for (final item in items) {
      final project = projects[item.projectId];
      if (project == null) continue;
      final band = TrayEntry.bandFor(item, at);
      if (band == null) continue;
      entries.add(TrayEntry(task: item, project: project, band: band));
    }
    entries.sort((a, b) {
      final byBand = a.band.rank.compareTo(b.band.rank);
      if (byBand != 0) return byBand;
      final aDue = a.task.dueAt?.millisecondsSinceEpoch ?? 1 << 62;
      final bDue = b.task.dueAt?.millisecondsSinceEpoch ?? 1 << 62;
      return aDue.compareTo(bDue);
    });
    return entries;
  }

  Future<TaskItem> addTask({
    required int projectId,
    required String title,
    String? notes,
    DateTime? dueAt,
    TaskUrgency urgency = TaskUrgency.later,
    TaskRepeat repeat = TaskRepeat.none,
  }) {
    final now = DateTime.now();
    return _items.insert(
      TaskItem(
        projectId: projectId,
        title: cleanName(title),
        notes: notes == null || notes.trim().isEmpty ? null : notes.trim(),
        dueAt: dueAt,
        urgency: urgency,
        repeat: repeat,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<void> updateTask(TaskItem item) =>
      _items.update(item.copyWith(updatedAt: DateTime.now()));

  Future<void> snoozeTask(int id, DateTime until) async {
    final existing = await _items.byId(id);
    if (existing == null || existing.isDone) return;
    await _items.update(
      existing.copyWith(snoozedUntil: until, updatedAt: DateTime.now()),
    );
  }

  /// Completes a one-shot task, or advances a repeating one to the next due.
  Future<TaskItem?> completeTask(int id, {DateTime? at}) {
    return _db.db.transaction((txn) async {
      final items = TaskDao(txn);
      final projects = ProjectDao(txn);
      final existing = await items.byId(id);
      if (existing == null || existing.isDone) return existing;
      final when = at ?? DateTime.now();
      final project = await projects.byId(existing.projectId);

      late final TaskItem next;
      if (existing.repeat == TaskRepeat.none) {
        next = existing.copyWith(completedAt: when, updatedAt: when);
      } else {
        final from = existing.dueAt ?? when;
        next = existing.copyWith(
          dueAt: nextDueAfter(from, existing.repeat),
          clearSnooze: true,
          updatedAt: when,
        );
      }
      await items.update(next);

      await ActivityWriter(txn).write(
        ActivityEntry(
          appId: TasksActivity.appId,
          kind: TasksActivity.taskDone,
          title: existing.title,
          subtitle: project?.name,
          occurredAt: when,
          refTable: TasksActivity.itemsTable,
          refId: existing.id,
        ),
      );
      return next;
    });
  }

  /// Puts a finished task back on the open list.
  Future<void> reopenTask(int id) async {
    final existing = await _items.byId(id);
    if (existing == null || !existing.isDone) return;
    await _items.update(
      existing.copyWith(clearCompleted: true, updatedAt: DateTime.now()),
    );
  }

  Future<void> deleteTask(int id) => _items.delete(id);

  Future<List<TaskItem>> pendingAlerts({DateTime? now}) =>
      _items.pendingAlerts(now ?? DateTime.now());
}
