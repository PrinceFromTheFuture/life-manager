/// Identifiers the tasks app writes into the shared feed.
abstract final class TasksActivity {
  /// Must match `TasksApp.id`; persisted in `activity.app_id`.
  static const String appId = 'tasks';

  static const String projectAdded = 'project_added';
  static const String taskDone = 'task_done';

  static const String projectsTable = 'tasks_projects';
  static const String itemsTable = 'tasks_items';

  static DateTime startOfDay(DateTime date) {
    final local = date.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  /// Exclusive end of the in-tray window: midnight after the third local day.
  static DateTime endOfSoonWindow(DateTime now) =>
      startOfDay(now).add(const Duration(days: 4));
}
