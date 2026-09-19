import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shopping_list/apps/calendar/calendar_app.dart';
import 'package:shopping_list/apps/calendar/state/providers.dart';
import 'package:shopping_list/apps/calendar/ui/navigate_launch.dart';
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
import 'package:shopping_list/hub/today_rail.dart';
import 'package:shopping_list/core/design/widgets/app_icon.dart';

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
    const calendar = CalendarApp();
    final brightness = Theme.of(context).brightness;
    final receiptsInk = receipts.ink.of(brightness);
    final calendarInk = calendar.ink.of(brightness);
    final onInk = brightness == Brightness.light ? palette.paper : palette.print;

    void openAccount() => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const AccountScreen()),
        );

    void addExpense() => openMiniApp(
          context,
          receipts,
          initialScreen: (_) => const ExpenseSheet(),
          fullscreenDialog: true,
        );

    void navigate() => openMiniApp(
          context,
          calendar,
          initialScreen: (_) => const NavigateLaunch(),
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
                child: const AppIcon(SolarIcons.User, size: 18),
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
            icon: const AppIcon(SolarIcons.Settings),
            tooltip: 'Settings',
            onPressed: openAccount,
          ),
          const SizedBox(width: Space.xs),
        ],
      ),
      body: RefreshIndicator(
        color: palette.print,
        backgroundColor: palette.paperShade,
        onRefresh: () async {
          ref.invalidate(activityFeedProvider);
          ref.invalidate(todayTicketsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.only(bottom: Space.lg),
          children: [
            Launcher(apps: registry.apps),
            const TodayRail(),
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
      // Two first-class hub actions, each in its app's ink: go somewhere,
      // or photograph a receipt. Same plate language as Receipts' accounts bar.
      bottomNavigationBar: Material(
        color: palette.paper,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            Space.lg,
            Space.md,
            Space.lg,
            Space.md + MediaQuery.paddingOf(context).bottom,
          ),
          child: Row(
            children: [
              _HubPlate(
                color: calendarInk,
                onColor: onInk,
                semanticLabel: 'Navigate',
                onPressed: navigate,
                child: AppIcon(SolarIcons.MapPoint, size: 22, color: onInk),
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                child: FilledButton.icon(
                  onPressed: addExpense,
                  style: FilledButton.styleFrom(
                    backgroundColor: receiptsInk,
                    foregroundColor: onInk,
                    minimumSize: const Size(0, Plate.height),
                    shape: InkPlateBorder(
                      borderRadius: Radii.key,
                      side: BorderSide(
                        color: Color.lerp(receiptsInk, palette.print, 0.38)!,
                        width: 1.5,
                      ),
                      insetColor: Plate.inset(onInk),
                    ),
                  ),
                  icon: const AppIcon(SolarIcons.CameraMinimalistic, size: 18),
                  label: const Text('Add expense'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HubPlate extends StatelessWidget {
  const _HubPlate({
    required this.color,
    required this.onColor,
    required this.semanticLabel,
    required this.onPressed,
    required this.child,
  });

  final Color color;
  final Color onColor;
  final String semanticLabel;
  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: color,
        shape: InkPlateBorder(
          borderRadius: Radii.key,
          side: BorderSide(
            color: Color.lerp(color, context.thermal.print, 0.38)!,
            width: 1.5,
          ),
          insetColor: Plate.inset(onColor),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: Plate.height,
            height: Plate.height,
            child: Center(child: child),
          ),
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
