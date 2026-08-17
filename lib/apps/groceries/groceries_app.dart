import 'package:flutter/material.dart';

import 'package:shopping_list/apps/groceries/data/groceries_activity.dart';
import 'package:shopping_list/apps/groceries/data/groceries_migrations.dart';
import 'package:shopping_list/apps/groceries/ui/history/trip_detail_screen.dart';
import 'package:shopping_list/apps/groceries/ui/list/list_screen.dart';
import 'package:shopping_list/core/activity/activity_entry.dart';
import 'package:shopping_list/core/activity/activity_row_shell.dart';
import 'package:shopping_list/core/app/mini_app.dart';
import 'package:shopping_list/core/app/mini_app_host.dart';
import 'package:shopping_list/core/db/migration.dart';

/// The grocery list, as a mini-app.
class GroceriesApp implements MiniApp {
  const GroceriesApp();

  /// Persisted in `activity.app_id` and `schema_versions.module_id`. Changing
  /// it would orphan existing history and re-run migrations from scratch.
  @override
  String get id => GroceryActivity.appId;

  @override
  String get name => 'Groceries';

  @override
  String get tagline => 'Build it, shop it, keep the slip.';

  /// Carbon-copy violet — the ink of duplicate slips.
  @override
  AppInk get ink => const AppInk(
        light: Color(0xFF5B4B8A),
        dark: Color(0xFF9B8AD1),
      );

  @override
  IconData get icon => Icons.local_grocery_store_outlined;

  @override
  ModuleMigrations get migrations => groceriesMigrations;

  @override
  Widget buildHome(BuildContext context) => const ListScreen();

  /// None, deliberately.
  ///
  /// Opening the grocery list *is* adding to it — the add field is already the
  /// first thing your thumb lands on. A hub shortcut would just be a second
  /// route to the same screen, and a row of quick actions that mostly duplicate
  /// the launcher above it is clutter rather than speed.
  @override
  List<QuickAction> quickActions(BuildContext context) => const [];

  @override
  Widget buildActivityRow(BuildContext context, ActivityEntry entry) {
    return ActivityRowShell(
      ink: ink.of(Theme.of(context).brightness),
      title: entry.title,
      subtitle: entry.subtitle,
      amountMinor: entry.amountMinor,
      onTap: entry.refId == null
          ? null
          : () => openMiniApp(
                context,
                this,
                initialScreen: (_) => TripDetailScreen(tripId: entry.refId!),
              ),
    );
  }

  @override
  Route<void>? routeForActivity(ActivityEntry entry) {
    if (entry.refTable != GroceryActivity.tripsTable || entry.refId == null) {
      return null;
    }
    return MaterialPageRoute<void>(
      builder: (_) => TripDetailScreen(tripId: entry.refId!),
    );
  }
}
