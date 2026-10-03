import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:shopping_list/apps/calendar/data/expand/days.dart';
import 'package:shopping_list/apps/calendar/state/providers.dart';
import 'package:shopping_list/apps/calendar/ui/ask_screen.dart';
import 'package:shopping_list/apps/calendar/ui/drawer/event_drawer.dart';
import 'package:shopping_list/apps/calendar/ui/drawer/month_view.dart';
import 'package:shopping_list/apps/calendar/ui/grid/grid_metrics.dart';
import 'package:shopping_list/apps/calendar/ui/grid/week_grid.dart';
import 'package:shopping_list/apps/calendar/ui/grid/week_nav.dart';
import 'package:shopping_list/apps/calendar/ui/night.dart';
import 'package:shopping_list/apps/calendar/ui/week_strip.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/design/widgets/app_icon.dart';
import 'package:shopping_list/core/design/widgets/night_plate.dart' show NightPlate;

/// The week, as one surface.
///
/// The top bar names the month and carries everything that is not the week
/// itself. Under it the strip holds all seven days; under that the grid
/// shows three at a time and pages a week when pulled past its edge. Every
/// edit happens in a drawer over this screen, never on another page.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key, this.occurredAt});

  /// Lands on this moment: its week, its day, its hour. Used by the hub feed
  /// and the today rail.
  final DateTime? occurredAt;

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen>
    with TickerProviderStateMixin {
  late final WeekNav _nav = WeekNav(
    vsync: this,
    week: widget.occurredAt ?? DateTime.now(),
  );

  @override
  void initState() {
    super.initState();
    _nav.addListener(_publishWeek);
    final at = widget.occurredAt;
    if (at != null) _nav.reveal(at, time: true, animate: false);
    _publishWeek();
  }

  @override
  void dispose() {
    _nav
      ..removeListener(_publishWeek)
      ..dispose();
    super.dispose();
  }

  /// The AI and deep links read the week from the provider; the screen owns
  /// the transition and writes once a week is chosen.
  void _publishWeek() {
    final week = _nav.week;
    if (ref.read(calendarWeekProvider) == week) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(calendarWeekProvider.notifier).state = week;
    });
  }

  bool get _reduced => MediaQuery.disableAnimationsOf(context);

  void _today() {
    HapticFeedback.selectionClick();
    _nav.reveal(DateTime.now(), time: true, animate: !_reduced);
  }

  /// "+" lands on the next half hour today when today is in view, otherwise
  /// at nine on the first day the grid shows.
  Future<void> _create(BuildContext context) async {
    unawaited(HapticFeedback.lightImpact());
    final now = DateTime.now();
    final lens = _nav.lens.value;
    final todayIndex = Days.between(_nav.week, now);
    DateTime start;
    if (todayIndex >= 0 && todayIndex < 7 && lens.shows(todayIndex)) {
      final minutes = ((Days.minutesOf(now) ~/ 30) + 1) * 30;
      start = Days.atMinutes(now, minutes.clamp(0, 24 * 60 - 60));
    } else {
      start = Days.atMinutes(Days.addDays(_nav.week, lens.firstDay), 9 * 60);
    }
    await showEventDrawer(context, startsAt: start);
  }

  List<int> _loads(DateTime week) =>
      dayLoads(week, ref.watch(weekTicketsProvider(week)).valueOrNull ?? const []);

  @override
  Widget build(BuildContext context) {
    ref.listen<DateTime>(calendarWeekProvider, (previous, next) {
      if (Days.startOfWeek(next) != _nav.week) {
        _nav.go(next, animate: !_reduced);
      }
    });

    return NightTheme(
      child: Builder(
        builder: (context) => Scaffold(
          backgroundColor: Night.ground,
          floatingActionButton: _AddButton(onTap: () => _create(context)),
          // Every horizontal drag on this screen belongs to the calendar —
          // the strip and the grid claim theirs first, and this soaks up the
          // rest so the life shell never pages out from under a week.
          body: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragStart: (_) {},
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  _TopBar(
                    nav: _nav,
                    onMonth: () => showMonthDrawer(
                      context,
                      week: _nav.week,
                      onPick: (day) => _nav.reveal(day, animate: !_reduced),
                    ),
                    onToday: _today,
                    onRoutines: () => showRoutinesDrawer(context),
                    onPlaces: () => showPlacesDrawer(context),
                    onAsk: () => AskScreen.open(
                      context,
                      day: Days.addDays(_nav.week, _nav.lens.value.firstDay),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      GridMetrics.gutter - Space.sm,
                      0,
                      Space.sm,
                      Space.xs,
                    ),
                    child: WeekStrip(
                      nav: _nav,
                      loads: _loads,
                      onTapDay: (day) {
                        HapticFeedback.selectionClick();
                        _nav.reveal(day, animate: !_reduced);
                      },
                    ),
                  ),
                  Expanded(
                    child: WeekGrid(
                      nav: _nav,
                      onOpenEvent: (ticket) => showEventDrawer(context, ticket: ticket),
                      onCreate: (start) => showEventDrawer(context, startsAt: start),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.nav,
    required this.onMonth,
    required this.onToday,
    required this.onRoutines,
    required this.onPlaces,
    required this.onAsk,
  });

  final WeekNav nav;
  final VoidCallback onMonth;
  final VoidCallback onToday;
  final VoidCallback onRoutines;
  final VoidCallback onPlaces;
  final VoidCallback onAsk;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.md, Space.sm),
      child: Row(
        children: [
          Expanded(
            child: AnimatedBuilder(
              animation: Listenable.merge([nav, nav.lens]),
              builder: (context, _) {
                final shown = Days.addDays(nav.week, nav.lens.value.firstDay);
                final now = DateTime.now();
                final today = Days.between(nav.week, now);
                final todayInView = today >= 0 && today < 7 && nav.lens.value.shows(today);
                return Row(
                  children: [
                    Flexible(
                      child: _MonthTitle(
                        month: DateTime(shown.year, shown.month),
                        direction: nav.direction,
                        onTap: onMonth,
                      ),
                    ),
                    const SizedBox(width: Space.sm),
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: todayInView ? 0 : 1,
                      child: IgnorePointer(
                        ignoring: todayInView,
                        child: _TodayPill(onTap: onToday),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          NightPlate(icon: SolarIcons.Repeat, label: 'Routines', size: 40, onTap: onRoutines),
          const SizedBox(width: Space.sm),
          NightPlate(icon: SolarIcons.MapPoint, label: 'Places', size: 40, onTap: onPlaces),
          const SizedBox(width: Space.sm),
          NightPlate(icon: SolarIcons.StarsMinimalistic, label: 'Ask', size: 40, onTap: onAsk),
        ],
      ),
    );
  }
}

class _MonthTitle extends StatelessWidget {
  const _MonthTitle({
    required this.month,
    required this.direction,
    required this.onTap,
  });

  final DateTime month;
  final int direction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final now = DateTime.now();
    final label = DateFormat(month.year == now.year ? 'MMMM' : 'MMM y').format(month);
    return Semantics(
      button: true,
      label: '$label, open month',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: ClipRect(
                child: AnimatedSwitcher(
                  duration: reduced ? Duration.zero : GridMetrics.reveal,
                  switchInCurve: GridMetrics.ease,
                  switchOutCurve: GridMetrics.ease.flipped,
                  layoutBuilder: (current, previous) => Stack(
                    alignment: Alignment.centerLeft,
                    children: [...previous, if (current != null) current],
                  ),
                  transitionBuilder: (child, animation) {
                    final incoming = child.key == ValueKey(label);
                    final from = (incoming ? 1.0 : -1.0) * direction * 0.6;
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween(begin: Offset(0, from), end: Offset.zero).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: Text(
                    label,
                    key: ValueKey(label),
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                    softWrap: false,
                    style: Type.display.copyWith(fontSize: 30, height: 1.1, color: Night.bone),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            const AppIcon(SolarIcons.AltArrowDown, size: 18, color: Night.mist),
          ],
        ),
      ),
    );
  }
}

class _TodayPill extends StatelessWidget {
  const _TodayPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Today',
      child: Material(
        color: Night.tile,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        child: InkWell(
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: 7),
            child: Text('Today', style: Type.item.copyWith(fontSize: 14, color: Night.bone)),
          ),
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'New event',
      child: Material(
        color: Night.bone,
        shape: const CircleBorder(),
        elevation: 0,
        shadowColor: Colors.black,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: const SizedBox(
            width: 58,
            height: 58,
            child: Center(
              child: AppIcon(SolarIcons.AddCircle, size: 28, color: Night.ink),
            ),
          ),
        ),
      ),
    );
  }
}
