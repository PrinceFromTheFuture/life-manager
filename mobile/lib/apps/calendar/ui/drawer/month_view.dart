import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:shopping_list/apps/calendar/data/expand/days.dart';
import 'package:shopping_list/apps/calendar/data/expand/slices.dart';
import 'package:shopping_list/apps/calendar/data/models/ticket.dart';
import 'package:shopping_list/apps/calendar/state/providers.dart';
import 'package:shopping_list/apps/calendar/ui/drawer/drawer_parts.dart';
import 'package:shopping_list/apps/calendar/ui/grid/grid_metrics.dart';
import 'package:shopping_list/apps/calendar/ui/night.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/design/widgets/app_icon.dart';
import 'package:shopping_list/core/design/widgets/multi_view_drawer.dart';

/// Six weeks at a glance, for jumping further than a swipe. The week on
/// screen is banded; a tap anywhere lands the grid on that day.
Future<void> showMonthDrawer(
  BuildContext context, {
  required DateTime week,
  required ValueChanged<DateTime> onPick,
}) {
  return showMultiViewDrawer<void>(
    context: context,
    initial: 'month',
    views: {
      'month': DrawerView(builder: (_) => MonthView(week: week, onPick: onPick)),
    },
  );
}

class MonthView extends ConsumerStatefulWidget {
  const MonthView({super.key, required this.week, required this.onPick});

  final DateTime week;
  final ValueChanged<DateTime> onPick;

  @override
  ConsumerState<MonthView> createState() => _MonthViewState();
}

class _MonthViewState extends ConsumerState<MonthView> {
  late DateTime _month = _monthOf(widget.week);
  int _direction = 1;
  double _drag = 0;

  /// The month a week mostly belongs to: the one its Wednesday is in.
  static DateTime _monthOf(DateTime week) {
    final mid = Days.addDays(Days.startOfWeek(week), 3);
    return DateTime(mid.year, mid.month);
  }

  void _step(int direction) {
    HapticFeedback.selectionClick();
    setState(() {
      _direction = direction;
      _month = DateTime(_month.year, _month.month + direction);
    });
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final now = DateTime.now();
    final sameYear = _month.year == now.year;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DrawerViewHeader(
          title: DateFormat(sameYear ? 'MMMM' : 'MMMM y').format(_month),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              NightRoundButton(
                icon: SolarIcons.AltArrowLeft,
                label: 'Previous month',
                onTap: () => _step(-1),
              ),
              const SizedBox(width: Space.sm),
              NightRoundButton(
                icon: SolarIcons.AltArrowRight,
                label: 'Next month',
                onTap: () => _step(1),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.md),
          child: Row(
            children: [
              for (final letter in const ['S', 'M', 'T', 'W', 'T', 'F', 'S'])
                Expanded(
                  child: Center(
                    child: Text(
                      letter,
                      style: Type.eyebrow.copyWith(fontSize: 10, color: Night.mist),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: Space.sm),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: (d) => _drag += d.delta.dx,
          onHorizontalDragEnd: (d) {
            final v = d.velocity.pixelsPerSecond.dx;
            if (_drag < -GridMetrics.stripDistance || v < -GridMetrics.stripVelocity) {
              _step(1);
            } else if (_drag > GridMetrics.stripDistance || v > GridMetrics.stripVelocity) {
              _step(-1);
            }
            _drag = 0;
          },
          child: ClipRect(
            child: AnimatedSwitcher(
              duration: reduced ? Duration.zero : GridMetrics.weekSlide,
              switchInCurve: GridMetrics.ease,
              switchOutCurve: GridMetrics.ease.flipped,
              layoutBuilder: (current, previous) => Stack(
                alignment: Alignment.topCenter,
                children: [...previous, if (current != null) current],
              ),
              transitionBuilder: (child, animation) {
                final incoming = child.key == ValueKey(_month);
                final from = incoming ? _direction.toDouble() : -_direction.toDouble();
                return SlideTransition(
                  position: Tween(begin: Offset(from, 0), end: Offset.zero).animate(animation),
                  child: FadeTransition(opacity: animation, child: child),
                );
              },
              child: _MonthGrid(
                key: ValueKey(_month),
                month: _month,
                week: Days.startOfWeek(widget.week),
                onPick: (day) {
                  HapticFeedback.selectionClick();
                  MultiViewDrawer.of(context).close();
                  widget.onPick(day);
                },
              ),
            ),
          ),
        ),
        DrawerFooter(
          children: [
            DrawerSecondaryButton(
              label: 'Today',
              icon: SolarIcons.CalendarMark,
              onTap: () {
                MultiViewDrawer.of(context).close();
                widget.onPick(Days.startOfDay(DateTime.now()));
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _MonthGrid extends ConsumerWidget {
  const _MonthGrid({
    super.key,
    required this.month,
    required this.week,
    required this.onPick,
  });

  final DateTime month;
  final DateTime week;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tickets = ref.watch(monthTicketsProvider(month)).valueOrNull ?? const <Ticket>[];
    final first = Days.startOfWeek(month);
    final now = DateTime.now();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.md),
      child: Column(
        children: [
          for (var row = 0; row < 6; row++)
            Builder(
              builder: (context) {
                final rowStart = Days.addDays(first, row * 7);
                final current = rowStart == week;
                return Container(
                  height: 50,
                  margin: const EdgeInsets.only(bottom: 2),
                  decoration: BoxDecoration(
                    color: current ? const Color(0x14FFFFFF) : Colors.transparent,
                    borderRadius: const BorderRadius.all(Radius.circular(14)),
                  ),
                  child: Row(
                    children: [
                      for (var i = 0; i < 7; i++)
                        Expanded(
                          child: _Day(
                            day: Days.addDays(rowStart, i),
                            inMonth: Days.addDays(rowStart, i).month == month.month,
                            today: Days.isSameDay(Days.addDays(rowStart, i), now),
                            load: Slices.onDay(Days.addDays(rowStart, i), tickets).length,
                            onTap: onPick,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _Day extends StatelessWidget {
  const _Day({
    required this.day,
    required this.inMonth,
    required this.today,
    required this.load,
    required this.onTap,
  });

  final DateTime day;
  final bool inMonth;
  final bool today;
  final int load;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final dots = load == 0 ? 0 : (load <= 2 ? 1 : (load <= 5 ? 2 : 3));
    final color = today ? Night.ink : (inMonth ? Night.bone : Night.mist.withValues(alpha: 0.5));
    return Semantics(
      button: true,
      label: '${DateFormat('EEEE d MMMM').format(day)}, $load events',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(day),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: today
                  ? const BoxDecoration(color: Night.bone, shape: BoxShape.circle)
                  : null,
              child: Text(
                '${day.day}',
                style: Type.display.copyWith(fontSize: 15, height: 1, color: color),
              ),
            ),
            const SizedBox(height: 2),
            SizedBox(
              height: 4,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < dots; i++)
                    Container(
                      width: 4,
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color: inMonth ? Night.mist : Night.mist.withValues(alpha: 0.4),
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
