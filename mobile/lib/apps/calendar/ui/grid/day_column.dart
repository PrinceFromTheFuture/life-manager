import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import 'package:shopping_list/apps/calendar/data/expand/days.dart';
import 'package:shopping_list/apps/calendar/data/expand/overlaps.dart';
import 'package:shopping_list/apps/calendar/data/expand/slices.dart';
import 'package:shopping_list/apps/calendar/data/models/place.dart';
import 'package:shopping_list/apps/calendar/data/models/ticket.dart';
import 'package:shopping_list/apps/calendar/ui/grid/event_card.dart';
import 'package:shopping_list/apps/calendar/ui/grid/grid_metrics.dart';
import 'package:shopping_list/apps/calendar/ui/night.dart';

/// Callbacks a column forwards from its cards and its empty space.
class ColumnActions {
  const ColumnActions({
    required this.onTapEmpty,
    required this.onTapEvent,
    required this.onLift,
    required this.onMove,
    required this.onDrop,
    required this.onCancel,
  });

  final void Function(DateTime day, double y) onTapEmpty;
  final ValueChanged<Ticket> onTapEvent;
  final ValueChanged<LiftStart> onLift;
  final ValueChanged<Offset> onMove;
  final VoidCallback onDrop;
  final VoidCallback onCancel;
}

/// A placeholder block where a new event is about to go.
class Ghost {
  const Ghost({required this.start, required this.duration});

  final DateTime start;
  final int duration;
}

/// One day: hour rules, its events laid out side by side, and the now line.
class DayColumn extends StatelessWidget {
  const DayColumn({
    super.key,
    required this.day,
    required this.tickets,
    required this.places,
    required this.width,
    required this.scale,
    required this.now,
    required this.compact,
    required this.actions,
    this.liftKey,
    this.ghost,
  });

  final DateTime day;
  final List<Ticket> tickets;
  final Map<int, Place> places;
  final double width;
  final TimeScale scale;
  final DateTime now;
  final bool compact;
  final ColumnActions actions;
  final String? liftKey;
  final Ghost? ghost;

  @override
  Widget build(BuildContext context) {
    final placed = Overlaps.place(
      Slices.onDay(day, tickets),
      minMinutes: GridMetrics.minCardMinutes,
    );
    final today = Days.isSameDay(day, now);
    final pastDay = day.isBefore(Days.startOfDay(now));
    final inset = compact ? 1.0 : 2.0;
    final lane = width - inset * 2;
    final ghost = this.ghost;

    return SizedBox(
      width: width,
      height: scale.dayHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) =>
                  actions.onTapEmpty(day, details.localPosition.dy),
              child: CustomPaint(
                painter: _Rules(
                  scale: scale,
                  pastUntil: pastDay
                      ? 24 * 60
                      : (today ? Days.minutesOf(now) : 0),
                ),
              ),
            ),
          ),
          for (final item in placed)
            _place(item, lane: lane, inset: inset),
          if (today)
            Positioned(
              top: scale.px(Days.minutesOf(now)) - 1,
              left: 0,
              right: 0,
              height: 2,
              child: const IgnorePointer(child: _NowLine()),
            ),
          if (ghost != null && Days.isSameDay(ghost.start, day))
            Positioned(
              key: const ValueKey('ghost'),
              top: scale.px(Days.minutesOf(ghost.start)) + 1,
              left: inset,
              width: lane,
              height: scale.px(ghost.duration) - 2,
              child: const IgnorePointer(child: SpringIn(child: _GhostBlock())),
            ),
        ],
      ),
    );
  }

  Widget _place(PlacedSlice item, {required double lane, required double inset}) {
    final slice = item.slice;
    final ticket = slice.ticket;
    final share = lane / item.columns;
    final top = scale.px(slice.topMinutes);
    final drawn = slice.durationMinutes < GridMetrics.minCardMinutes
        ? GridMetrics.minCardMinutes
        : slice.durationMinutes;
    final height = scale.px(drawn) - 2;
    final lifted = ticket.key == liftKey;
    final place =
        ticket.locationId == null ? null : places[ticket.locationId!];

    return Positioned(
      key: ValueKey('${ticket.key}@${slice.topMinutes}'),
      top: top + 1,
      left: inset + item.column * share + (item.column == 0 ? 0 : 1),
      width: share - (item.column == 0 ? 0 : 1) - (item.columns > 1 ? 1 : 0),
      height: height,
      child: AnimatedOpacity(
        opacity: lifted ? 0.25 : 1,
        duration: GridMetrics.viewSwitch,
        child: EventTarget(
          ticket: ticket,
          onTap: () => actions.onTapEvent(ticket),
          onLift: actions.onLift,
          onMove: actions.onMove,
          onDrop: actions.onDrop,
          onCancel: actions.onCancel,
          child: EventCard(
            ticket: ticket,
            place: place,
            height: height,
            compact: compact,
            past: !ticket.endsAt.isAfter(now),
            continuation: slice.continuesFromPrevious,
          ),
        ),
      ),
    );
  }
}

class _Rules extends CustomPainter {
  const _Rules({required this.scale, required this.pastUntil});

  final TimeScale scale;
  final int pastUntil;

  @override
  void paint(Canvas canvas, Size size) {
    if (pastUntil > 0) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, scale.px(pastUntil)),
        Paint()..color = const Color(0x40000000),
      );
    }
    final hour = Paint()
      ..color = Night.line
      ..strokeWidth = 1;
    final half = Paint()
      ..color = Night.hairline
      ..strokeWidth = 1;
    for (var h = 0; h < 24; h++) {
      final y = scale.px(h * 60) + 0.5;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), hour);
      final hy = scale.px(h * 60 + 30) + 0.5;
      canvas.drawLine(Offset(0, hy), Offset(size.width, hy), half);
    }
    canvas.drawLine(
      Offset(size.width - 0.5, 0),
      Offset(size.width - 0.5, size.height),
      half,
    );
  }

  @override
  bool shouldRepaint(_Rules old) =>
      old.scale.hourHeight != scale.hourHeight || old.pastUntil != pastUntil;
}

class _NowLine extends StatelessWidget {
  const _NowLine();

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Positioned.fill(child: ColoredBox(color: Night.bone)),
        Positioned(
          left: -4,
          top: -3,
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Night.bone,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }
}

class _GhostBlock extends StatelessWidget {
  const _GhostBlock();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Night.bone.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: Night.bone.withValues(alpha: 0.85), width: 1.5),
      ),
    );
  }
}

/// Grows in on the candidate spring. Used by the ghost and the picker block.
class SpringIn extends StatefulWidget {
  const SpringIn({super.key, required this.child});

  final Widget child;

  @override
  State<SpringIn> createState() => _SpringInState();
}

class _SpringInState extends State<SpringIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController.unbounded(vsync: this);

  @override
  void initState() {
    super.initState();
    _c.animateWith(SpringSimulation(GridMetrics.candidate, 0, 1, 0));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) _c.value = 1;
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = _c.value;
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.scale(scale: 0.9 + 0.1 * t, child: child),
        );
      },
      child: widget.child,
    );
  }
}
