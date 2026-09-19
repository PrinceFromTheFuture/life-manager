import 'package:flutter/material.dart';

import 'package:shopping_list/apps/calendar/data/expand/days.dart';
import 'package:shopping_list/apps/calendar/data/expand/slices.dart';
import 'package:shopping_list/apps/calendar/data/models/place.dart';
import 'package:shopping_list/apps/calendar/data/models/ticket.dart';
import 'package:shopping_list/apps/calendar/ui/board/ticket_card.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';

/// Vertical timetable. Hours in Space Mono; a scorch line is now.
class DayBoard extends StatelessWidget {
  const DayBoard({
    super.key,
    required this.day,
    required this.tickets,
    required this.places,
    required this.controller,
    required this.hourHeight,
    this.liftKey,
    this.compact = false,
    this.showGutter = true,
    this.scrollable = true,
    this.onTap,
    this.onBlankTap,
    this.onLongPressStart,
  });

  static const double defaultHourHeight = 56;
  static const double minHourHeight = 32;
  static const double maxHourHeight = 112;
  static const int hours = 24;
  static const double gutter = 44;

  final DateTime day;
  final List<Ticket> tickets;
  final Map<int, Place> places;
  final ScrollController controller;
  final double hourHeight;
  final String? liftKey;
  final bool compact;
  final bool showGutter;
  final bool scrollable;
  final ValueChanged<Ticket>? onTap;
  final ValueChanged<DateTime>? onBlankTap;
  final void Function(Ticket ticket, LongPressStartDetails details)?
      onLongPressStart;

  static double heightOf(int durationMinutes, double hourHeight) =>
      (durationMinutes / 60) * hourHeight;

  static double topOfMinutes(int minutes, double hourHeight) =>
      (minutes / 60) * hourHeight;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    final now = DateTime.now();
    final showNow = Days.isSameDay(day, now);
    final slices = Slices.onDay(day, tickets);
    final packed = _pack(slices);

    final body = SizedBox(
        height: hours * hourHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (var h = 0; h < hours; h++)
              Positioned(
                top: h * hourHeight,
                left: 0,
                right: 0,
                height: hourHeight,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showGutter)
                      SizedBox(
                        width: gutter,
                        child: Text(
                          h.toString().padLeft(2, '0'),
                          style: Type.mono.copyWith(
                            color: palette.faded,
                            fontSize: compact ? 9 : 11,
                          ),
                        ),
                      )
                    else
                      const SizedBox(width: 0),
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapUp: onBlankTap == null
                            ? null
                            : (details) {
                                final minutes = Days.snapMinutes(
                                  ((h * 60) +
                                          (details.localPosition.dy /
                                                  hourHeight *
                                                  60)
                                              .round())
                                      .clamp(0, 24 * 60 - 15),
                                );
                                onBlankTap!(Days.atMinutes(day, minutes));
                              },
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(
                                color:
                                    palette.perforation.withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            for (final layout in packed)
              Positioned(
                top: topOfMinutes(layout.slice.topMinutes, hourHeight) + 1,
                left: (showGutter ? gutter : 0) + 2 + layout.indent * (compact ? 6 : 10),
                right: compact ? 2 : 8,
                height: (heightOf(layout.slice.durationMinutes, hourHeight) - 2)
                    .clamp(compact ? 18.0 : 28.0, hours * hourHeight),
                child: TicketCard(
                  ticket: layout.slice.ticket,
                  place: layout.slice.ticket.locationId == null
                      ? null
                      : places[layout.slice.ticket.locationId!],
                  lifted: layout.slice.ticket.key == liftKey,
                  compact: compact,
                  continuation: layout.slice.continuesFromPrevious,
                  onTap: onTap == null
                      ? null
                      : () => onTap!(layout.slice.ticket),
                  onLongPressStart: onLongPressStart == null
                      ? null
                      : (d) => onLongPressStart!(layout.slice.ticket, d),
                ),
              ),
            if (showNow)
              Positioned(
                top: topOfMinutes(Days.minutesOf(now), hourHeight),
                left: showGutter ? gutter : 0,
                right: 0,
                child: CustomPaint(
                  painter: _NowPainter(color: palette.scorch),
                  size: const Size(double.infinity, 2),
                ),
              ),
          ],
        ),
      );
    if (scrollable) {
      return SingleChildScrollView(
        controller: controller,
        physics: const ClampingScrollPhysics(),
        child: body,
      );
    }
    return body;
  }

  static List<_Laid> _pack(List<DaySlice> slices) {
    final laid = <_Laid>[];
    for (final slice in slices) {
      final start = slice.topMinutes;
      final end = start + slice.durationMinutes;
      var indent = 0;
      for (final other in laid) {
        final otherEnd = other.slice.topMinutes + other.slice.durationMinutes;
        if (other.slice.topMinutes < end && otherEnd > start) {
          indent = other.indent + 1;
        }
      }
      laid.add(_Laid(slice: slice, indent: indent.clamp(0, 3)));
    }
    return laid;
  }
}

class _Laid {
  const _Laid({required this.slice, required this.indent});

  final DaySlice slice;
  final int indent;
}

class _NowPainter extends CustomPainter {
  const _NowPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset.zero, Offset(size.width, 0), paint);
  }

  @override
  bool shouldRepaint(covariant _NowPainter old) => old.color != color;
}
