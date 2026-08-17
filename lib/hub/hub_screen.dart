import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shopping_list/core/activity/providers.dart';
import 'package:shopping_list/core/app/registry.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/design/widgets/perforation.dart';
import 'package:shopping_list/hub/account_screen.dart';
import 'package:shopping_list/hub/activity_feed.dart';
import 'package:shopping_list/hub/launcher.dart';
import 'package:shopping_list/hub/quick_action_drawer.dart';

/// The shell's home screen.
///
/// Three jobs, in priority order: get into an app in one tap, start something
/// without opening an app first, and show what has been happening across all
/// of them. It carries no colour of its own — every coloured mark on this
/// screen belongs to a mini-app, which is what makes the ink stamps readable
/// as identity rather than decoration.
class HubScreen extends ConsumerWidget {
  const HubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.thermal;
    final registry = ref.watch(registryProvider);
    final feed = ref.watch(activityFeedProvider);

    void openAccount() => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const AccountScreen()),
        );

    return Scaffold(
      backgroundColor: palette.paper,
      appBar: AppBar(
        titleSpacing: Space.lg,
        title: InkWell(
          onTap: openAccount,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: palette.paperShade,
                foregroundColor: palette.print,
                child: const Icon(Icons.person, size: 18),
              ),
              const SizedBox(width: Space.sm),
              Text(
                "Amir's Life Manager",
                style: Type.item.copyWith(color: palette.print),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: openAccount,
          ),
          const SizedBox(width: Space.xs),
        ],
      ),
      body: RefreshIndicator(
        color: palette.print,
        backgroundColor: palette.paperShade,
        onRefresh: () async => ref.invalidate(activityFeedProvider),
        child: ListView(
          padding: const EdgeInsets.only(bottom: Space.xxl),
          children: [
            Launcher(apps: registry.apps),
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
      // A single, fixed control rather than a row that grows one button per
      // app quick action — that row would already be crowded at two apps and
      // unusable at five. Everything it offers lives in the drawer instead.
      floatingActionButton: FloatingActionButton(
        onPressed: () => showQuickActions(context),
        tooltip: 'Start something',
        backgroundColor: palette.print,
        foregroundColor: palette.paper,
        child: const Icon(Icons.bolt),
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
