import 'package:flutter/material.dart';

import 'package:shopping_list/apps/calendar/data/expand/days.dart';
import 'package:shopping_list/apps/calendar/data/models/place.dart';
import 'package:shopping_list/apps/calendar/data/models/ticket.dart';
import 'package:shopping_list/apps/calendar/ui/board/day_board.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';

/// Seven day-columns sharing one vertical scroll, so a 23:00 event that
/// runs past midnight continues in the next column at 00:00.
class WeekBoard extends StatelessWidget {
  const WeekBoard({
    super.key,
    required this.anchor,
    required this.tickets,
    required this.places,
    required this.controller,
    required this.hourHeight,
    this.liftKey,
    this.onTap,
    this.onBlankTap,
    this.onLongPressStart,
  });

  final DateTime anchor;
  final List<Ticket> tickets;
  final Map<int, Place> places;
  final ScrollController controller;
  final double hourHeight;
  final String? liftKey;
  final ValueChanged<Ticket>? onTap;
  final ValueChanged<DateTime>? onBlankTap;
  final void Function(Ticket ticket, LongPressStartDetails details)?
      onLongPressStart;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    final days = Days.weekOf(anchor);

    return SingleChildScrollView(
      controller: controller,
      physics: const ClampingScrollPhysics(),
      child: SizedBox(
        height: DayBoard.hours * hourHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: DayBoard.gutter,
              child: Column(
                children: [
                  for (var h = 0; h < DayBoard.hours; h++)
                    SizedBox(
                      height: hourHeight,
                      child: Text(
                        h.toString().padLeft(2, '0'),
                        style: Type.mono.copyWith(
                          color: palette.faded,
                          fontSize: 9,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            for (final day in days)
              Expanded(
                child: DayBoard(
                  day: day,
                  tickets: tickets,
                  places: places,
                  controller: controller,
                  hourHeight: hourHeight,
                  liftKey: liftKey,
                  compact: true,
                  showGutter: false,
                  scrollable: false,
                  onTap: onTap,
                  onBlankTap: onBlankTap,
                  onLongPressStart: onLongPressStart,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
