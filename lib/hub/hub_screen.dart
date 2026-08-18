import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shopping_list/apps/receipts/receipts_app.dart';
import 'package:shopping_list/apps/receipts/ui/expense_sheet.dart';
import 'package:shopping_list/core/activity/providers.dart';
import 'package:shopping_list/core/app/mini_app_host.dart';
import 'package:shopping_list/core/app/registry.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/design/widgets/ink_plate.dart';
import 'package:shopping_list/core/design/widgets/perforation.dart';
import 'package:shopping_list/hub/account_screen.dart';
import 'package:shopping_list/hub/activity_feed.dart';
import 'package:shopping_list/hub/launcher.dart';

/// The shell's home screen.
///
/// Three jobs, in priority order: get into an app in one tap, photograph a
/// receipt without opening Receipts first, and show what has been happening
/// across all of them. It carries no colour of its own — every coloured mark
/// on this screen belongs to a mini-app, which is what makes the ink stamps
/// readable as identity rather than decoration.
class HubScreen extends ConsumerWidget {
  const HubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.thermal;
    final registry = ref.watch(registryProvider);
    final feed = ref.watch(activityFeedProvider);
    const receipts = ReceiptsApp();
    final brightness = Theme.of(context).brightness;
    final receiptsInk = receipts.ink.of(brightness);
    final onReceiptsInk =
        brightness == Brightness.light ? palette.paper : palette.print;

    void openAccount() => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const AccountScreen()),
        );

    void addExpense() => openMiniApp(
          context,
          receipts,
          initialScreen: (_) => const ExpenseSheet(),
          fullscreenDialog: true,
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
      // Photographing a receipt cannot wait for you to open Receipts. This is
      // that app's capture, on the hub, in that app's ink — one tap from the
      // pavement after paying. It says what it does; a camera-only mark would
      // have to be learned.
      floatingActionButton: FloatingActionButton.extended(
        onPressed: addExpense,
        tooltip: 'Add expense',
        backgroundColor: receiptsInk,
        foregroundColor: onReceiptsInk,
        icon: const Icon(Icons.photo_camera_outlined, size: 18),
        label: const Text('Add expense'),
        shape: InkPlateBorder(
          borderRadius: Radii.key,
          side: BorderSide(
            color: Color.lerp(receiptsInk, palette.print, 0.38)!,
            width: 1.5,
          ),
          insetColor: Plate.inset(onReceiptsInk),
        ),
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
