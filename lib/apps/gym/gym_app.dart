import 'package:flutter/material.dart';

import 'package:shopping_list/apps/gym/data/gym_activity.dart';
import 'package:shopping_list/apps/gym/data/gym_migrations.dart';
import 'package:shopping_list/apps/gym/ui/day_pass_screen.dart';
import 'package:shopping_list/apps/gym/ui/record_set_screen.dart';
import 'package:shopping_list/core/activity/activity_entry.dart';
import 'package:shopping_list/core/activity/activity_row_shell.dart';
import 'package:shopping_list/core/app/mini_app.dart';
import 'package:shopping_list/core/app/mini_app_host.dart';
import 'package:shopping_list/core/db/migration.dart';

/// Gym progress, as a mini-app.
class GymApp implements MiniApp {
  const GymApp();

  @override
  String get id => GymActivity.appId;

  @override
  String get name => 'Gym';

  @override
  String get tagline => 'Log a set. The day holds it.';

  /// Oxidized iron — lifting-belt leather, rust on a used plate. Distinct
  /// from groceries violet and ledger blue, and still one accent on paper.
  @override
  AppInk get ink => const AppInk(
        light: Color(0xFF6E3B2F),
        dark: Color(0xFFD9A090),
      );

  @override
  IconData get icon => Icons.fitness_center_outlined;

  @override
  ModuleMigrations get migrations => gymMigrations;

  @override
  Widget buildHome(BuildContext context) => const DayPassScreen();

  /// Worth a hub shortcut, like receipts.
  ///
  /// The value of this app is logging the set you just finished, while you
  /// are still standing at the rack. Making that one tap from the home
  /// screen rather than two is the difference between a training log and a
  /// thing you mean to fill in later.
  @override
  List<QuickAction> quickActions(BuildContext context) => [
        QuickAction(
          label: 'Record a set',
          icon: Icons.fitness_center_outlined,
          builder: (_) => RecordSetScreen(forDay: DateTime.now()),
        ),
      ];

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
                initialScreen: (_) => DayPassScreen(
                  day: GymActivity.dateFromKey(entry.refId!),
                ),
              ),
    );
  }

  @override
  Route<void>? routeForActivity(ActivityEntry entry) {
    if (entry.refTable != GymActivity.daysRef || entry.refId == null) {
      return null;
    }
    return MaterialPageRoute<void>(
      builder: (_) => DayPassScreen(day: GymActivity.dateFromKey(entry.refId!)),
    );
  }
}
