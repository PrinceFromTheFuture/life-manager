import 'package:flutter/material.dart';

import 'package:shopping_list/apps/calendar/data/expand/days.dart';
import 'package:shopping_list/apps/calendar/data/models/place.dart';
import 'package:shopping_list/apps/calendar/data/models/ticket.dart';
import 'package:shopping_list/apps/calendar/ui/grid/day_column.dart';
import 'package:shopping_list/apps/calendar/ui/grid/day_snap_physics.dart';
import 'package:shopping_list/apps/calendar/ui/grid/grid_metrics.dart';
import 'package:shopping_list/apps/calendar/ui/night.dart';
import 'package:shopping_list/core/design/theme.dart';

/// One week of columns under their pinned headers.
///
/// The body is a horizontal scroller around a vertical one, both locked to
/// their axis. The headers are not a third scroll view: they are translated
/// by the horizontal offset in the same frame, so they can never drift.
class WeekBody extends StatefulWidget {
  const WeekBody({
    super.key,
    required this.week,
    required this.tickets,
    required this.places,
    required this.columns,
    required this.scale,
    required this.gate,
    required this.now,
    required this.actions,
    required this.initialH,
    required this.initialV,
    required this.onScroll,
    this.liftKey,
    this.ghost,
  });

  final DateTime week;
  final List<Ticket> tickets;
  final Map<int, Place> places;
  final ColumnScale columns;
  final TimeScale scale;
  final SnapGate gate;
  final DateTime now;
  final ColumnActions actions;
  final double initialH;
  final double initialV;

  /// Called on every scroll of either axis. The grid only listens to the
  /// active body.
  final VoidCallback onScroll;
  final String? liftKey;
  final Ghost? ghost;

  @override
  State<WeekBody> createState() => WeekBodyState();
}

class WeekBodyState extends State<WeekBody> {
  late final ScrollController horizontal =
      ScrollController(initialScrollOffset: widget.initialH)
        ..addListener(widget.onScroll);
  late final ScrollController vertical =
      ScrollController(initialScrollOffset: widget.initialV)
        ..addListener(widget.onScroll);

  double get h => horizontal.hasClients ? horizontal.offset : widget.initialH;

  double get v => vertical.hasClients ? vertical.offset : widget.initialV;

  @override
  void dispose() {
    horizontal.dispose();
    vertical.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final columns = widget.columns;
    final compact = columns.days >= GridMetrics.compactDensity;
    final days = Days.weekOf(widget.week);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: GridMetrics.header,
          child: ClipRect(
            child: AnimatedBuilder(
              animation: horizontal,
              builder: (context, child) => Transform.translate(
                offset: Offset(-h, 0),
                child: child,
              ),
              child: OverflowBox(
                alignment: Alignment.centerLeft,
                minWidth: columns.content,
                maxWidth: columns.content,
                child: Row(
                  children: [
                    for (final day in days)
                      _ColumnHeader(
                        day: day,
                        width: columns.width,
                        now: widget.now,
                        compact: compact,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const ColoredBox(color: Night.line, child: SizedBox(height: 1)),
        Expanded(
          child: SingleChildScrollView(
            controller: horizontal,
            scrollDirection: Axis.horizontal,
            physics: DaySnapPhysics(
              columnWidth: columns.width,
              gate: widget.gate,
            ),
            child: SizedBox(
              width: columns.content,
              child: SingleChildScrollView(
                controller: vertical,
                child: SizedBox(
                  height: widget.scale.dayHeight,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final day in days)
                        DayColumn(
                          key: ValueKey(day),
                          day: day,
                          tickets: widget.tickets,
                          places: widget.places,
                          width: columns.width,
                          scale: widget.scale,
                          now: widget.now,
                          compact: compact,
                          actions: widget.actions,
                          liftKey: widget.liftKey,
                          ghost: widget.ghost,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ColumnHeader extends StatelessWidget {
  const _ColumnHeader({
    required this.day,
    required this.width,
    required this.now,
    required this.compact,
  });

  static const _names = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];

  final DateTime day;
  final double width;
  final DateTime now;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final today = Days.isSameDay(day, now);
    final past = day.isBefore(Days.startOfDay(now));
    final name = _names[day.weekday % 7];
    final tone = today ? Night.bone : (past ? Night.mist.withValues(alpha: 0.7) : Night.mist);

    return SizedBox(
      width: width,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            compact ? name.substring(0, 1) : name,
            style: Type.eyebrow.copyWith(
              color: tone,
              fontSize: 10,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: compact ? 24 : 30,
            height: compact ? 24 : 30,
            alignment: Alignment.center,
            decoration: today
                ? const BoxDecoration(color: Night.bone, shape: BoxShape.circle)
                : null,
            child: Text(
              '${day.day}',
              style: Type.display.copyWith(
                fontSize: compact ? 14 : 18,
                height: 1,
                letterSpacing: -0.3,
                color: today ? Night.ink : (past ? Night.mist : Night.bone),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
