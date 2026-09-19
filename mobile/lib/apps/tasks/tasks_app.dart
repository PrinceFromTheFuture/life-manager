import 'package:flutter/material.dart';

import 'package:shopping_list/apps/tasks/data/tasks_activity.dart';
import 'package:shopping_list/apps/tasks/data/tasks_migrations.dart';
import 'package:shopping_list/apps/tasks/ui/tasks_shell.dart';
import 'package:shopping_list/core/activity/activity_entry.dart';
import 'package:shopping_list/core/activity/activity_row_shell.dart';
import 'package:shopping_list/core/app/mini_app.dart';
import 'package:shopping_list/core/app/mini_app_host.dart';
import 'package:shopping_list/core/db/migration.dart';
import 'package:shopping_list/core/design/widgets/app_icon.dart';

/// Life projects, as a mini-app.
class TasksApp implements MiniApp {
  const TasksApp();

  @override
  String get id => TasksActivity.appId;

  @override
  String get name => 'Tasks';

  @override
  String get tagline => 'What is due. Which life it belongs to.';

  /// Kraft / manila hanging-file. Distinct from groceries violet, receipts
  /// ledger and gym iron, and still one accent on paper.
  @override
  AppInk get ink => const AppInk(
        light: Color(0xFF7A5429),
        dark: Color(0xFFD4B896),
      );

  @override
  SolarIconData get icon => SolarIcons.ChecklistMinimalistic;

  @override
  ModuleMigrations get migrations => tasksMigrations;

  @override
  Widget buildHome(BuildContext context) => const TasksShell();

  @override
  List<QuickAction> quickActions(BuildContext context) => const [];

  @override
  Widget buildActivityRow(BuildContext context, ActivityEntry entry) {
    return ActivityRowShell(
      ink: ink.of(Theme.of(context).brightness),
      title: entry.title,
      subtitle: entry.subtitle,
      onTap: entry.refId == null
          ? null
          : () => openMiniApp(
                context,
                this,
                initialScreen: (_) => TasksShell(
                  focusProjectId:
                      entry.refTable == TasksActivity.projectsTable
                          ? entry.refId
                          : null,
                  focusTaskId: entry.refTable == TasksActivity.itemsTable
                      ? entry.refId
                      : null,
                ),
              ),
    );
  }

  @override
  Route<void>? routeForActivity(ActivityEntry entry) {
    if (entry.refId == null) return null;
    return MaterialPageRoute<void>(
      builder: (_) => TasksShell(
        focusProjectId: entry.refTable == TasksActivity.projectsTable
            ? entry.refId
            : null,
        focusTaskId:
            entry.refTable == TasksActivity.itemsTable ? entry.refId : null,
      ),
    );
  }
}
