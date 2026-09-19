import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shopping_list/apps/tasks/data/models/project.dart';
import 'package:shopping_list/apps/tasks/data/models/task_item.dart';
import 'package:shopping_list/apps/tasks/data/models/tray_entry.dart';
import 'package:shopping_list/apps/tasks/data/task_alerts.dart';
import 'package:shopping_list/apps/tasks/data/tasks_repository.dart';
import 'package:shopping_list/core/activity/providers.dart';
import 'package:shopping_list/core/providers.dart';

final tasksRepositoryProvider = Provider<TasksRepository>(
  (ref) => TasksRepository(ref.watch(databaseProvider)),
);

/// Bumped after every write so the spine, tray and project page refresh.
final tasksTickProvider = StateProvider<int>((ref) => 0);

final livingProjectsProvider = FutureProvider<List<Project>>((ref) {
  ref.watch(tasksTickProvider);
  return ref.watch(tasksRepositoryProvider).livingProjects();
});

final trayProvider = FutureProvider<List<TrayEntry>>((ref) {
  ref.watch(tasksTickProvider);
  return ref.watch(tasksRepositoryProvider).tray();
});

final projectProvider =
    FutureProvider.autoDispose.family<Project?, int>((ref, id) {
  ref.watch(tasksTickProvider);
  return ref.watch(tasksRepositoryProvider).project(id);
});

final openTasksProvider =
    FutureProvider.autoDispose.family<List<TaskItem>, int>((ref, projectId) {
  ref.watch(tasksTickProvider);
  return ref.watch(tasksRepositoryProvider).openTasks(projectId);
});

final doneTasksProvider =
    FutureProvider.autoDispose.family<List<TaskItem>, int>((ref, projectId) {
  ref.watch(tasksTickProvider);
  return ref.watch(tasksRepositoryProvider).doneTasks(projectId);
});

class TasksController {
  TasksController(this.ref);

  final Ref ref;

  TasksRepository get _repo => ref.read(tasksRepositoryProvider);

  void _tick() {
    ref.read(tasksTickProvider.notifier).state++;
    ref.invalidate(activityFeedProvider);
    unawaited(_rebuildAlerts());
  }

  Future<void> _rebuildAlerts() async {
    final items = await _repo.pendingAlerts();
    await TaskAlerts.instance.rebuild(items);
  }

  Future<void> rebuildAlerts() => _rebuildAlerts();

  Future<Project> addProject({
    required String name,
    String? inkId,
    String? iconId,
  }) async {
    final project = await _repo.addProject(
      name: name,
      inkId: inkId,
      iconId: iconId,
    );
    _tick();
    return project;
  }

  Future<void> updateProject(Project project) async {
    await _repo.updateProject(project);
    _tick();
  }

  Future<void> archiveProject(int id) async {
    await _repo.archiveProject(id);
    _tick();
  }

  Future<TaskItem> addTask({
    required int projectId,
    required String title,
    String? notes,
    DateTime? dueAt,
    TaskUrgency urgency = TaskUrgency.later,
    TaskRepeat repeat = TaskRepeat.none,
  }) async {
    final item = await _repo.addTask(
      projectId: projectId,
      title: title,
      notes: notes,
      dueAt: dueAt,
      urgency: urgency,
      repeat: repeat,
    );
    _tick();
    return item;
  }

  Future<void> updateTask(TaskItem item) async {
    await _repo.updateTask(item);
    _tick();
  }

  Future<void> snoozeTask(int id, DateTime until) async {
    await _repo.snoozeTask(id, until);
    _tick();
  }

  Future<void> completeTask(int id) async {
    await _repo.completeTask(id);
    _tick();
  }

  Future<void> reopenTask(int id) async {
    await _repo.reopenTask(id);
    _tick();
  }

  Future<void> deleteTask(int id) async {
    await _repo.deleteTask(id);
    _tick();
  }
}

final tasksControllerProvider =
    Provider<TasksController>((ref) => TasksController(ref));
