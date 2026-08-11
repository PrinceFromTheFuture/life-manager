import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shopping_list/core/activity/providers.dart';
import 'package:shopping_list/core/app/mini_app.dart';
import 'package:shopping_list/core/app/registry.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/design/widgets/perforation.dart';
import 'package:shopping_list/hub/activity_feed.dart';
import 'package:shopping_list/hub/launcher.dart';

/// The shell's home screen.
///
/// Two jobs, in priority order: get into an app in one tap, and show what has
/// been happening across all of them. It carries no colour of its own — every
/// coloured mark on this screen belongs to a mini-app, which is what makes the
/// ink stamps readable as identity rather than decoration.
class HubScreen extends ConsumerWidget {
  const HubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.thermal;
    final registry = ref.watch(registryProvider);
    final feed = ref.watch(activityFeedProvider);

    return Scaffold(
      backgroundColor: palette.paper,
      appBar: AppBar(title: const Text('Spindle')),
      body: RefreshIndicator(
        color: palette.print,
        backgroundColor: palette.paperShade,
        onRefresh: () async => ref.invalidate(activityFeedProvider),
        child: ListView(
          padding: const EdgeInsets.only(bottom: Space.xxl),
          children: [
            Launcher(apps: registry.apps),
            const SizedBox(height: Space.lg),
            _QuickActions(apps: registry.apps),
            feed.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(Space.xxl),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(Space.lg),
                child: Text(
                  '$e',
                  style: Type.caption.copyWith(color: palette.faded),
                ),
              ),
              data: (days) =>
                  days.isEmpty ? const _NothingYet() : ActivityFeed(days: days),
            ),
          ],
        ),
      ),
    );
  }
}

/// Actions apps offer without being opened.
///
/// Only rendered when an app actually contributes one — an empty strip of
/// chrome is worse than no strip.
class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.apps});

  final List<MiniApp> apps;

  @override
  Widget build(BuildContext context) {
    final actions = [
      for (final app in apps)
        ...app.quickActions(context).map((a) => (app, a)),
    ];
    if (actions.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.lg),
      child: Row(
        children: [
          for (final (app, action) in actions) ...[
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => action.onInvoke(context),
                icon: Icon(action.icon, size: 18),
                label: Text(action.label),
                style: OutlinedButton.styleFrom(
                  foregroundColor: app.ink.of(Theme.of(context).brightness),
                  side: BorderSide(
                    color: app.ink.of(Theme.of(context).brightness),
                    width: 1.5,
                  ),
                ),
              ),
            ),
            if ((app, action) != actions.last) const SizedBox(width: Space.md),
          ],
        ],
      ),
    );
  }
}

class _NothingYet extends StatelessWidget {
  const _NothingYet();

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;

    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.lg, Space.xxl, Space.lg, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PerforatedRule(),
          const SizedBox(height: Space.lg),
          Text(
            'Nothing on the spindle yet.',
            style: Type.display.copyWith(color: palette.print, fontSize: 26),
          ),
          const SizedBox(height: Space.md),
          Text(
            'Finish a shop or log an expense and it lands here, newest first.',
            style: Type.body.copyWith(color: palette.faded),
          ),
        ],
      ),
    );
  }
}
