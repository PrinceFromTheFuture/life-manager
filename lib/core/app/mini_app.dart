import 'package:flutter/material.dart';

import 'package:shopping_list/core/activity/activity_entry.dart';
import 'package:shopping_list/core/db/migration.dart';

/// The accent colour a mini-app is "printed" in.
///
/// This is the **only** colour a mini-app owns. Every other token in
/// `ThermalPalette` — paper, print, faded, perforation, scorch, settled — is
/// identical across the whole product. Keeping that rule is what stops a
/// growing collection of apps turning into a generic multicoloured dashboard,
/// and it means "one accent per screen" still holds literally, with the accent
/// simply differing by app.
@immutable
class AppInk {
  const AppInk({required this.light, required this.dark});

  final Color light;
  final Color dark;

  Color of(Brightness brightness) =>
      brightness == Brightness.light ? light : dark;
}

/// Something a mini-app offers directly from the hub, without opening it.
class QuickAction {
  const QuickAction({
    required this.label,
    required this.icon,
    required this.onInvoke,
  });

  /// Says exactly what happens: "Add expense", not "New".
  final String label;

  final IconData icon;
  final void Function(BuildContext context) onInvoke;
}

/// One app inside the life manager.
///
/// The contract exists so that adding an app is **one folder and one
/// registration** — no central file grows a new branch, no shared schema file
/// is edited, and nothing anywhere switches on an app id. Each module owns its
/// own schema, its own screens, its own feed rows and its own deep links.
abstract class MiniApp {
  /// Stable identifier, persisted in `activity.app_id`. Never change it once
  /// rows exist — it is how saved history finds its way back to this module.
  String get id;

  /// Shown in the launcher, in the user's language.
  String get name;

  AppInk get ink;
  IconData get icon;

  /// This module's schema, owned entirely by it. See [Migration].
  ModuleMigrations get migrations;

  /// The app's own root screen.
  Widget buildHome(BuildContext context);

  /// Offered on the hub. Empty is fine.
  List<QuickAction> quickActions(BuildContext context) => const [];

  /// Renders one of this app's own rows in the shared feed.
  ///
  /// The hub delegates rather than interpreting, so it never has to learn what
  /// an expense or a shopping trip is — and a module can change how its history
  /// looks without touching the hub.
  Widget buildActivityRow(BuildContext context, ActivityEntry entry);

  /// Where tapping that row should go. Null means the row isn't tappable.
  Route<void>? routeForActivity(ActivityEntry entry);
}
