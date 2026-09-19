import 'package:shopping_list/apps/calendar/data/expand/days.dart';
import 'package:shopping_list/apps/calendar/data/models/ticket.dart';

/// The portion of a ticket that belongs on one local day.
///
/// A 23:00–01:00 event is two slices: the last hour of its start day, then
/// the first hour of the next. Without this, the next day would paint the
/// ticket at 23:00 again — off the bottom, so it simply disappeared.
class DaySlice {
  const DaySlice({
    required this.ticket,
    required this.topMinutes,
    required this.durationMinutes,
    required this.continuesFromPrevious,
    required this.continuesIntoNext,
  });

  final Ticket ticket;

  /// Minutes from this day's midnight to the visible top.
  final int topMinutes;

  /// Visible length on this day, in minutes.
  final int durationMinutes;

  final bool continuesFromPrevious;
  final bool continuesIntoNext;
}

abstract final class Slices {
  /// Visible pieces of [tickets] on [day], including overnight spill from
  /// the day before and onto the day after.
  static List<DaySlice> onDay(DateTime day, List<Ticket> tickets) {
    final start = Days.startOfDay(day);
    final end = Days.startOfNextDay(start);
    final laid = <DaySlice>[];
    for (final ticket in tickets) {
      if (!ticket.startsAt.isBefore(end) || !ticket.endsAt.isAfter(start)) {
        continue;
      }
      final visibleStart =
          ticket.startsAt.isBefore(start) ? start : ticket.startsAt;
      final visibleEnd = ticket.endsAt.isAfter(end) ? end : ticket.endsAt;
      final minutes = visibleEnd.difference(visibleStart).inMinutes;
      if (minutes <= 0) continue;
      laid.add(
        DaySlice(
          ticket: ticket,
          topMinutes: Days.minutesOf(visibleStart),
          durationMinutes: minutes,
          continuesFromPrevious: ticket.startsAt.isBefore(start),
          continuesIntoNext: ticket.endsAt.isAfter(end),
        ),
      );
    }
    laid.sort((a, b) {
      final byTop = a.topMinutes.compareTo(b.topMinutes);
      if (byTop != 0) return byTop;
      return a.ticket.key.compareTo(b.ticket.key);
    });
    return laid;
  }
}
