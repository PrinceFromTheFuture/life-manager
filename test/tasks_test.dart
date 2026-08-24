import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/apps/tasks/data/models/task_item.dart';
import 'package:shopping_list/apps/tasks/data/models/tray_entry.dart';
import 'package:shopping_list/apps/tasks/data/tasks_activity.dart';
import 'package:shopping_list/apps/tasks/data/tasks_migrations.dart';
import 'package:shopping_list/apps/tasks/data/tasks_repository.dart';
import 'package:shopping_list/core/activity/activity_dao.dart';
import 'package:shopping_list/core/db/database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late AppDatabase database;
  late TasksRepository repo;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    database = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
      modules: [tasksMigrations],
    );
    repo = TasksRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('a new project is living and stamped on the feed', () async {
    final project = await repo.addProject(name: 'This app');
    expect(project.id, isNotNull);
    expect((await repo.livingProjects()).map((p) => p.name), ['This app']);

    final entries = await ActivityDao(database.db).recent();
    expect(entries, hasLength(1));
    expect(entries.single.appId, TasksActivity.appId);
    expect(entries.single.kind, TasksActivity.projectAdded);
    expect(entries.single.title, 'This app');
  });

  test('archiving hides a project from the living spine', () async {
    final project = await repo.addProject(name: 'Old house');
    await repo.archiveProject(project.id!);
    expect(await repo.livingProjects(), isEmpty);
    expect(await repo.project(project.id!), isNotNull);
  });

  group('in-tray', () {
    test('includes must, due-soon and later, excludes snoozed and completed', () async {
      final project = await repo.addProject(name: 'Life');
      final now = DateTime(2026, 8, 23, 12);

      await repo.addTask(
        projectId: project.id!,
        title: 'Must call',
        urgency: TaskUrgency.must,
      );
      await repo.addTask(
        projectId: project.id!,
        title: 'Due tomorrow',
        dueAt: DateTime(2026, 8, 24, 9),
      );
      await repo.addTask(
        projectId: project.id!,
        title: 'Overdue',
        dueAt: DateTime(2026, 8, 20, 9),
      );
      final snoozed = await repo.addTask(
        projectId: project.id!,
        title: 'Snoozed must',
        urgency: TaskUrgency.must,
      );
      await repo.snoozeTask(snoozed.id!, DateTime(2026, 8, 25, 9));
      final done = await repo.addTask(
        projectId: project.id!,
        title: 'Already done',
        urgency: TaskUrgency.must,
      );
      await repo.completeTask(done.id!, at: now);
      await repo.addTask(
        projectId: project.id!,
        title: 'Next month',
        dueAt: DateTime(2026, 9, 23, 9),
      );

      final tray = await repo.tray(now: now);
      final titles = tray.map((e) => e.task.title).toList();
      expect(titles, containsAll(['Must call', 'Due tomorrow', 'Overdue', 'Next month']));
      expect(titles, isNot(contains('Snoozed must')));
      expect(titles, isNot(contains('Already done')));

      expect(
        tray.firstWhere((e) => e.task.title == 'Overdue').band,
        TrayBand.overdue,
      );
      expect(
        tray.firstWhere((e) => e.task.title == 'Must call').band,
        TrayBand.must,
      );
      expect(
        tray.firstWhere((e) => e.task.title == 'Next month').band,
        TrayBand.later,
      );
    });
  });

  test('completing a one-shot task files it with the done work', () async {
    final project = await repo.addProject(name: 'This app');
    final task = await repo.addTask(
      projectId: project.id!,
      title: 'Ship a build',
    );
    final now = DateTime(2026, 8, 23, 12);
    await repo.completeTask(task.id!, at: now);

    expect(await repo.openTasks(project.id!), isEmpty);
    expect((await repo.doneTasks(project.id!)).single.title, 'Ship a build');

    await repo.reopenTask(task.id!);
    expect((await repo.openTasks(project.id!)).single.title, 'Ship a build');
    expect(await repo.doneTasks(project.id!), isEmpty);
  });

  test('completing a weekly task advances due_at by 7 days', () async {
    final project = await repo.addProject(name: 'This app');
    final due = DateTime(2026, 8, 23, 9);
    final task = await repo.addTask(
      projectId: project.id!,
      title: 'Ship a build',
      dueAt: due,
      repeat: TaskRepeat.weekly,
    );

    final next = await repo.completeTask(task.id!, at: due);
    expect(next!.completedAt, isNull);
    expect(next.dueAt, DateTime(2026, 8, 30, 9));
    expect(next.snoozedUntil, isNull);

    final entries = await ActivityDao(database.db).recent();
    expect(
      entries.where((e) => e.kind == TasksActivity.taskDone),
      hasLength(1),
    );
  });

  test('nextDueAfter clamps the end of the month', () {
    expect(
      nextDueAfter(DateTime(2026, 1, 31), TaskRepeat.monthly),
      DateTime(2026, 2, 28),
    );
  });
}
