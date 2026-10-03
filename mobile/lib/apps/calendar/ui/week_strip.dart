import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:shopping_list/apps/calendar/data/expand/days.dart';
import 'package:shopping_list/apps/calendar/data/expand/slices.dart';
import 'package:shopping_list/apps/calendar/data/models/ticket.dart';
import 'package:shopping_list/apps/calendar/ui/grid/grid_metrics.dart';
import 'package:shopping_list/apps/calendar/ui/grid/week_nav.dart';
import 'package:shopping_list/apps/calendar/ui/night.dart';
import 'package:shopping_list/core/design/theme.dart';

/// Events per day of [week], for the strip's load dots.
List<int> dayLoads(DateTime week, List<Ticket> tickets) => [
      for (final day in Days.weekOf(week)) Slices.onDay(day, tickets).length,
    ];

/// The whole week at a glance, and the lightest way to change it.
///
/// Seven chips, always all visible. A short swipe — 36 px or a flick — is
/// enough to turn the week, far less than a stock page view asks, and the
/// strip follows the finger at a damped rate so it feels like a nudge rather
/// than a drag. On the main screen a lens shows which days the grid has in
/// view; in the time picker the chosen day is filled instead.
class WeekStrip extends StatefulWidget {
  const WeekStrip({
    super.key,
    required this.nav,
    required this.loads,
    required this.onTapDay,
    this.showLens = true,
    this.selected,
  });

  final WeekNav nav;

  /// Events per day for a week's Sunday. Empty while it loads.
  final List<int> Function(DateTime week) loads;
  final ValueChanged<DateTime> onTapDay;
  final bool showLens;
  final DateTime? selected;

  static const double height = 64;

  @override
  State<WeekStrip> createState() => _WeekStripState();
}

class _WeekStripState extends State<WeekStrip>
    with SingleTickerProviderStateMixin {
  double _drag = 0;
  double _release = 0;
  int _releaseSerial = -1;

  late final AnimationController _back = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  )..addListener(() {
      setState(() => _drag = _backFrom * (1 - Curves.easeOutCubic.transform(_back.value)));
    });
  double _backFrom = 0;

  @override
  void dispose() {
    _back.dispose();
    super.dispose();
  }

  void _onUpdate(DragUpdateDetails details) {
    _back.stop();
    setState(() => _drag += details.delta.dx * GridMetrics.stripFollow);
  }

  void _onEnd(DragEndDetails details) {
    final travel = _drag / GridMetrics.stripFollow;
    final velocity = details.velocity.pixelsPerSecond.dx;
    var dir = 0;
    if (travel <= -GridMetrics.stripDistance || velocity <= -GridMetrics.stripVelocity) {
      dir = 1;
    } else if (travel >= GridMetrics.stripDistance || velocity >= GridMetrics.stripVelocity) {
      dir = -1;
    }
    if (dir == 0) {
      _backFrom = _drag;
      if (MediaQuery.disableAnimationsOf(context)) {
        setState(() => _drag = 0);
      } else {
        _back.forward(from: 0);
      }
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _release = _drag;
      _drag = 0;
    });
    widget.nav.step(dir, animate: !MediaQuery.disableAnimationsOf(context));
    _releaseSerial = widget.nav.serial;
  }

  @override
  Widget build(BuildContext context) {
    final nav = widget.nav;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: _onUpdate,
      onHorizontalDragEnd: _onEnd,
      child: SizedBox(
        height: WeekStrip.height,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return ClipRect(
              child: AnimatedBuilder(
                animation: Listenable.merge([nav, nav.progress]),
                builder: (context, _) {
                  final moving = nav.transitioning;
                  final t = moving ? nav.progress.value : 1.0;
                  final dir = nav.direction.toDouble();
                  final release = nav.serial == _releaseSerial ? _release : 0.0;
                  final carry = release * (1 - t);

                  Widget row(DateTime week, double dx, {required bool current}) {
                    return Positioned(
                      left: dx,
                      top: 0,
                      bottom: 0,
                      width: width,
                      child: _Row(
                        week: week,
                        loads: widget.loads(week),
                        lens: current && widget.showLens ? nav.lens : null,
                        selected: widget.selected,
                        onTapDay: widget.onTapDay,
                      ),
                    );
                  }

                  return Stack(
                    children: [
                      if (moving && nav.outgoing != null)
                        row(nav.outgoing!, -dir * width * t + carry, current: false),
                      if (moving)
                        row(nav.week, dir * width * (1 - t) + carry, current: true)
                      else ...[
                        if (_drag > 0)
                          row(Days.addDays(nav.week, -7), _drag - width, current: false),
                        row(nav.week, _drag, current: true),
                        if (_drag < 0)
                          row(Days.addDays(nav.week, 7), _drag + width, current: false),
                      ],
                    ],
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.week,
    required this.loads,
    required this.lens,
    required this.selected,
    required this.onTapDay,
  });

  static const _letters = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  final DateTime week;
  final List<int> loads;
  final ValueListenable<Lens>? lens;
  final DateTime? selected;
  final ValueChanged<DateTime> onTapDay;

  @override
  Widget build(BuildContext context) {
    final days = Days.weekOf(week);
    final now = DateTime.now();
    final lens = this.lens;

    return LayoutBuilder(
      builder: (context, constraints) {
        final chip = constraints.maxWidth / 7;
        return Stack(
          children: [
            if (lens != null)
              ValueListenableBuilder<Lens>(
                valueListenable: lens,
                builder: (context, value, _) {
                  final start = value.start.clamp(0.0, 7.0);
                  final end = (value.start + value.span).clamp(0.0, 7.0);
                  return Positioned(
                    left: start * chip + 2,
                    width: ((end - start) * chip - 4).clamp(0.0, double.infinity),
                    top: 4,
                    bottom: 4,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        color: Color(0x14FFFFFF),
                        borderRadius: BorderRadius.all(Radius.circular(14)),
                      ),
                    ),
                  );
                },
              ),
            Row(
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: _Chip(
                      day: days[i],
                      letter: _letters[i],
                      load: i < loads.length ? loads[i] : 0,
                      today: Days.isSameDay(days[i], now),
                      selected: selected != null && Days.isSameDay(days[i], selected!),
                      onTap: () => onTapDay(days[i]),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.day,
    required this.letter,
    required this.load,
    required this.today,
    required this.selected,
    required this.onTap,
  });

  final DateTime day;
  final String letter;
  final int load;
  final bool today;
  final bool selected;
  final VoidCallback onTap;

  /// One dot up to four events, two up to seven, three beyond.
  int get _dots => load == 0 ? 0 : (load <= 4 ? 1 : (load <= 7 ? 2 : 3));

  @override
  Widget build(BuildContext context) {
    final filled = selected;
    final text = filled ? Night.ink : Night.bone;
    return Semantics(
      button: true,
      selected: selected,
      label: '${day.day}, $load events',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
          child: AnimatedContainer(
            duration: GridMetrics.viewSwitch,
            decoration: BoxDecoration(
              color: filled ? Night.bone : Colors.transparent,
              borderRadius: const BorderRadius.all(Radius.circular(14)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  letter,
                  style: Type.eyebrow.copyWith(
                    fontSize: 10,
                    letterSpacing: 0.8,
                    color: filled ? Night.ink.withValues(alpha: 0.7) : Night.mist,
                  ),
                ),
                const SizedBox(height: 3),
                Container(
                  width: 26,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: today && !filled
                      ? const BoxDecoration(
                          color: Night.bone,
                          borderRadius: BorderRadius.all(Radius.circular(11)),
                        )
                      : null,
                  child: Text(
                    '${day.day}',
                    style: Type.display.copyWith(
                      fontSize: 16,
                      height: 1,
                      letterSpacing: -0.2,
                      color: today && !filled ? Night.ink : text,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 4,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < _dots; i++)
                        Container(
                          width: 4,
                          height: 4,
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: BoxDecoration(
                            color: filled ? Night.ink : Night.mist,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
