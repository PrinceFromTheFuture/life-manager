import 'package:shopping_list/apps/tasks/data/models/project.dart';
import 'package:shopping_list/apps/tasks/data/models/task_item.dart';
import 'package:shopping_list/apps/tasks/data/tasks_activity.dart';

/// Why an open task is sitting in the in-tray.
enum TrayBand {
  overdue,
  must,
  today,
  soon,
  later;

  String get label => switch (this) {
        TrayBand.overdue => 'LATE',
        TrayBand.must => 'MUST',
        TrayBand.today => 'TODAY',
        TrayBand.soon => 'SOON',
        TrayBand.later => 'LATER',
      };

  int get rank => switch (this) {
        TrayBand.overdue => 0,
        TrayBand.must => 1,
        TrayBand.today => 2,
        TrayBand.soon => 3,
        TrayBand.later => 4,
      };
}

/// A pulled card: the task plus the project it belongs to.
class TrayEntry {
  const TrayEntry({
    required this.task,
    required this.project,
    required this.band,
  });

  final TaskItem task;
  final Project project;
  final TrayBand band;

  static TrayBand? bandFor(TaskItem task, DateTime now) {
    if (task.isDone) return null;
    if (task.isSnoozedAt(now)) return null;

    final today = TasksActivity.startOfDay(now);
    final tomorrow = today.add(const Duration(days: 1));
    final soonEnd = TasksActivity.endOfSoonWindow(now);
    final due = task.dueAt;

    if (due != null && due.isBefore(today)) return TrayBand.overdue;
    if (task.urgency == TaskUrgency.must) return TrayBand.must;
    if (due == null) return TrayBand.later;
    if (due.isBefore(tomorrow)) return TrayBand.today;
    if (due.isBefore(soonEnd)) return TrayBand.soon;
    return TrayBand.later;
  }
}
