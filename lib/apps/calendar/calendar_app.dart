import 'package:flutter/material.dart';

import 'package:shopping_list/apps/calendar/data/calendar_activity.dart';
import 'package:shopping_list/apps/calendar/data/calendar_migrations.dart';
import 'package:shopping_list/apps/calendar/ui/calendar_shell.dart';
import 'package:shopping_list/core/activity/activity_entry.dart';
import 'package:shopping_list/core/activity/activity_row_shell.dart';
import 'package:shopping_list/core/app/mini_app.dart';
import 'package:shopping_list/core/app/mini_app_host.dart';
import 'package:shopping_list/core/db/migration.dart';
import 'package:shopping_list/core/design/widgets/app_icon.dart';

/// The blotter — what happens, and where you have to be.
class CalendarApp implements MiniApp {
  const CalendarApp();

  @override
  String get id => CalendarActivity.appId;

  @override
  String get name => 'Calendar';

  @override
  String get tagline => 'What happens. Where you have to be.';

  /// Iron-gall teal — timetable ink, harbour charts. Distinct from ledger
  /// blue, gym iron, tasks kraft and groceries violet.
  @override
  AppInk get ink => const AppInk(
        light: Color(0xFF2F5A5A),
        dark: Color(0xFF7EB0B0),
      );

  @override
  SolarIconData get icon => SolarIcons.Calendar;

  @override
  ModuleMigrations get migrations => calendarMigrations;

  @override
  Widget buildHome(BuildContext context) => const CalendarShell();

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
                initialScreen: (_) => CalendarShell(occurredAt: entry.occurredAt),
              ),
    );
  }

  @override
  Route<void>? routeForActivity(ActivityEntry entry) {
    if (entry.refId == null) return null;
    return MaterialPageRoute<void>(
      builder: (_) => CalendarShell(occurredAt: entry.occurredAt),
    );
  }
}
