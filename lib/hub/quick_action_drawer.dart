import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shopping_list/core/app/mini_app.dart';
import 'package:shopping_list/core/app/mini_app_host.dart';
import 'package:shopping_list/core/app/registry.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/design/widgets/inset_drawer.dart';
import 'package:shopping_list/core/design/widgets/perforation.dart';

/// Everything you can start from the hub without opening an app first.
///
/// Replaces the row of outlined buttons that used to sit under the launcher.
/// That row grew one button per app and would have become a wall; a drawer
/// holds any number behind a single control, and the control itself is the one
/// thing on the hub with a fixed, learnable position.
void showQuickActions(BuildContext context) {
  showInsetDrawer<void>(
    context: context,
    primary: (context) => const _QuickActionList(),
  );
}

class _QuickActionList extends ConsumerWidget {
  const _QuickActionList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.thermal;
    final registry = ref.watch(registryProvider);
    final scope = DrawerScope.of(context);

    final actions = <(MiniApp, QuickAction)>[
      for (final app in registry.apps)
        for (final action in app.quickActions(context)) (app, action),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.lg, 0),
          child: Text(
            'START SOMETHING',
            style: Type.eyebrow.copyWith(color: palette.faded),
          ),
        ),
        const SizedBox(height: Space.md),
        const PerforatedRule(indent: Space.lg),

        for (final (app, action) in actions)
          _DrawerRow(
            icon: action.icon,
            label: action.label,
            // The app's own ink, so you can see which app you are about to
            // land in before you tap.
            ink: app.ink.of(Theme.of(context).brightness),
            onTap: () {
              scope.close();
              openMiniApp(
                context,
                app,
                initialScreen: action.builder,
                fullscreenDialog: true,
              );
            },
          ),
      ],
    );
  }
}

class _DrawerRow extends StatelessWidget {
  const _DrawerRow({
    required this.icon,
    required this.label,
    required this.ink,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color ink;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.lg,
          vertical: Space.md + 4,
        ),
        child: Row(
          children: [
            Container(width: 3, height: 22, color: ink),
            const SizedBox(width: Space.md),
            Icon(icon, size: 20, color: ink),
            const SizedBox(width: Space.md),
            Expanded(
              child: Text(
                label,
                style: Type.item.copyWith(color: palette.print),
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: palette.faded),
          ],
        ),
      ),
    );
  }
}
