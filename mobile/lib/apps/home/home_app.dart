import 'package:flutter/material.dart';

import 'package:shopping_list/apps/home/data/home_migrations.dart';
import 'package:shopping_list/apps/home/ui/home_screen.dart';
import 'package:shopping_list/core/activity/activity_entry.dart';
import 'package:shopping_list/core/activity/activity_row_shell.dart';
import 'package:shopping_list/core/app/mini_app.dart';
import 'package:shopping_list/core/db/migration.dart';
import 'package:shopping_list/core/design/widgets/app_icon.dart';

/// The last launcher slot. A light surface for the redesign, layout only.
class HomeApp implements MiniApp {
  const HomeApp();

  @override
  String get id => 'home';

  @override
  String get name => 'Home';

  @override
  String get tagline => 'The day, in the light.';

  @override
  AppInk get ink => const AppInk(
        light: Color(0xFF090909),
        dark: Color(0xFFE4E4E4),
      );

  @override
  SolarIconData get icon => SolarIcons.Sun;

  @override
  bool get useNightTheme => false;

  @override
  ModuleMigrations get migrations => homeMigrations;

  @override
  List<QuickAction> quickActions(BuildContext context) => const [];

  @override
  Widget buildHome(BuildContext context) => const HomeView();

  @override
  Widget buildActivityRow(BuildContext context, ActivityEntry entry) {
    return ActivityRowShell(
      ink: ink.of(Theme.of(context).brightness),
      title: entry.title,
      subtitle: entry.subtitle,
    );
  }

  @override
  Route<void>? routeForActivity(ActivityEntry entry) => null;
}
