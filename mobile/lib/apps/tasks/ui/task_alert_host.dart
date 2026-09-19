import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shopping_list/apps/tasks/data/task_alerts.dart';
import 'package:shopping_list/apps/tasks/state/providers.dart';
import 'package:shopping_list/apps/tasks/tasks_app.dart';
import 'package:shopping_list/apps/tasks/ui/tasks_shell.dart';
import 'package:shopping_list/core/app/mini_app_host.dart';
import 'package:shopping_list/core/design/paper_snack.dart';

/// Rebuilds local task notifications from SQLite whenever the app is opened,
/// and routes a notification tap into Tasks on that card.
class TaskAlertHost extends ConsumerStatefulWidget {
  const TaskAlertHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<TaskAlertHost> createState() => _TaskAlertHostState();
}

class _TaskAlertHostState extends ConsumerState<TaskAlertHost> {
  @override
  void initState() {
    super.initState();
    TaskAlerts.instance.onOpenTask = _openTask;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      TaskAlerts.instance.flushPendingOpen();
      ref.read(tasksControllerProvider).rebuildAlerts();
    });
  }

  void _openTask(int taskId) {
    final context = paperSnackNavigatorKey.currentContext;
    if (context == null) return;
    openMiniApp(
      context,
      const TasksApp(),
      initialScreen: (_) => TasksShell(focusTaskId: taskId),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
