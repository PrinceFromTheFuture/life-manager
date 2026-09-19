import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/apps/calendar/data/expand/days.dart';
import 'package:shopping_list/apps/calendar/data/expand/recurrence.dart';
import 'package:shopping_list/apps/calendar/data/expand/slices.dart';
import 'package:shopping_list/apps/calendar/data/expand/weekdays.dart';
import 'package:shopping_list/apps/calendar/data/models/ticket.dart';
import 'package:shopping_list/apps/calendar/data/models/block.dart';
import 'package:shopping_list/apps/calendar/data/models/occurrence_override.dart';
import 'package:shopping_list/apps/calendar/data/models/series.dart';
import 'package:shopping_list/apps/calendar/data/navigate_links.dart';

Series _weekly({
  int id = 1,
  String title = 'Gym',
  int startMinutes = 18 * 60,
  int duration = 60,
  int weekdays = Weekdays.monday | Weekdays.wednesday | Weekdays.friday,
  DateTime? startsOn,
  DateTime? endsOn,
  int interval = 1,
  bool active = true,
}) =>
    Series(
      id: id,
      title: title,
      startMinutes: startMinutes,
      durationMinutes: duration,
      freq: SeriesFreq.weekly,
      interval: interval,
      weekdays: weekdays,
      startsOn: startsOn ?? DateTime(2026, 8, 2),
      endsOn: endsOn,
      active: active,
      createdAt: DateTime(2026, 8, 1),
    );

void main() {
  group('Days', () {
    test('a week starts on Sunday', () {
      expect(Days.startOfWeek(DateTime(2026, 8, 29)), DateTime(2026, 8, 23));
      expect(Days.startOfWeek(DateTime(2026, 8, 23)), DateTime(2026, 8, 23));
      expect(Days.startOfWeek(DateTime(2026, 8, 22)), DateTime(2026, 8, 16));
    });

    test('clamps a day past the end of a short month', () {
      expect(Days.dayOf(2026, 2, 31), DateTime(2026, 2, 28));
      expect(Days.dayOf(2024, 2, 31), DateTime(2024, 2, 29));
    });

    test('snaps minutes to a quarter hour', () {
      expect(Days.snapMinutes(67), 60);
      expect(Days.snapMinutes(70), 75);
      expect(Days.snapDuration(10), 15);
    });
  });

  group('Weekdays', () {
    test('Sunday is bit zero', () {
      expect(Weekdays.bitFor(DateTime(2026, 8, 23)), Weekdays.sunday);
      expect(Weekdays.bitFor(DateTime(2026, 8, 24)), Weekdays.monday);
      expect(Weekdays.has(Weekdays.monday, DateTime(2026, 8, 24)), isTrue);
      expect(Weekdays.has(Weekdays.monday, DateTime(2026, 8, 25)), isFalse);
    });
  });

  group('Recurrence', () {
    test('a weekday mask lands only on those days', () {
      final starts = Recurrence.originalStarts(
        _weekly(),
        from: DateTime(2026, 8, 23),
        to: DateTime(2026, 8, 30),
      );
      expect(
        starts.map((d) => DateTime(d.year, d.month, d.day)).toList(),
        [
          DateTime(2026, 8, 24),
          DateTime(2026, 8, 26),
          DateTime(2026, 8, 28),
        ],
      );
      expect(starts.first.hour, 18);
    });

    test('every other week skips the off week', () {
      final starts = Recurrence.originalStarts(
        _weekly(interval: 2, startsOn: DateTime(2026, 8, 23)),
        from: DateTime(2026, 8, 23),
        to: DateTime(2026, 9, 13),
      );
      final days = starts.map((d) => DateTime(d.year, d.month, d.day)).toList();
      expect(days, contains(DateTime(2026, 8, 24)));
      expect(days, isNot(contains(DateTime(2026, 8, 31))));
      expect(days, contains(DateTime(2026, 9, 7)));
    });

    test('a monthly series uses the last day of a short month', () {
      final series = Series(
        id: 2,
        title: 'Rent night',
        startMinutes: 20 * 60,
        durationMinutes: 30,
        freq: SeriesFreq.monthly,
        monthDay: 31,
        startsOn: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
      );
      final starts = Recurrence.originalStarts(
        series,
        from: DateTime(2026, 2, 1),
        to: DateTime(2026, 3, 1),
      );
      expect(starts.single, DateTime(2026, 2, 28, 20));
    });

    test('a daily series respects an end date', () {
      final series = Series(
        id: 3,
        title: 'Shift',
        startMinutes: 9 * 60,
        durationMinutes: 8 * 60,
        freq: SeriesFreq.daily,
        startsOn: DateTime(2026, 8, 24),
        endsOn: DateTime(2026, 8, 26),
        createdAt: DateTime(2026, 8, 1),
      );
      final starts = Recurrence.originalStarts(
        series,
        from: DateTime(2026, 8, 24),
        to: DateTime(2026, 8, 31),
      );
      expect(starts.length, 3);
      expect(starts.last, DateTime(2026, 8, 26, 9));
    });

    test('a skip leaves that occurrence out', () {
      final series = _weekly();
      final original = DateTime(2026, 8, 24, 18);
      final tickets = Recurrence.tickets(
        series: [series],
        blocks: const [],
        overrides: [
          OccurrenceOverride(
            seriesId: 1,
            originalStart: original,
            kind: OverrideKind.skip,
            createdAt: DateTime(2026, 8, 20),
          ),
        ],
        from: DateTime(2026, 8, 24),
        to: DateTime(2026, 8, 25),
      );
      expect(tickets, isEmpty);
    });

    test('a move keeps the original start and shows the new time', () {
      final series = _weekly();
      final original = DateTime(2026, 8, 24, 18);
      final tickets = Recurrence.tickets(
        series: [series],
        blocks: const [],
        overrides: [
          OccurrenceOverride(
            seriesId: 1,
            originalStart: original,
            kind: OverrideKind.move,
            startsAt: DateTime(2026, 8, 24, 20),
            durationMinutes: 45,
            createdAt: DateTime(2026, 8, 20),
          ),
        ],
        from: DateTime(2026, 8, 24),
        to: DateTime(2026, 8, 25),
      );
      expect(tickets, hasLength(1));
      expect(tickets.single.startsAt, DateTime(2026, 8, 24, 20));
      expect(tickets.single.originalStart, original);
      expect(tickets.single.durationMinutes, 45);
      expect(tickets.single.overridden, isTrue);
    });

    test('today leaves out a ticket that has already ended', () {
      final now = DateTime(2026, 8, 24, 18, 30);
      final tickets = Recurrence.today(
        series: [_weekly()],
        blocks: [
          Block(
            id: 9,
            title: 'Coffee',
            startsAt: DateTime(2026, 8, 24, 8),
            durationMinutes: 30,
            createdAt: DateTime(2026, 8, 24),
          ),
        ],
        overrides: const [],
        now: now,
      );
      expect(tickets.map((t) => t.title), ['Gym']);
    });

    test('a fly block sits beside a series ticket', () {
      final tickets = Recurrence.tickets(
        series: [_weekly()],
        blocks: [
          Block(
            id: 4,
            title: 'Parents',
            startsAt: DateTime(2026, 8, 24, 19, 30),
            durationMinutes: 90,
            createdAt: DateTime(2026, 8, 20),
          ),
        ],
        overrides: const [],
        from: DateTime(2026, 8, 24),
        to: DateTime(2026, 8, 25),
      );
      expect(tickets.map((t) => t.title), ['Gym', 'Parents']);
    });
  });

  group('NavigateLinks', () {
    test('geo names the place when it has one', () {
      expect(
        NavigateLinks.geo(32.08, 34.78, name: 'Home').toString(),
        'geo:32.08,34.78?q=32.08,34.78(Home)',
      );
    });

    test('the three apps get a deeplink each', () {
      expect(
        NavigateLinks.googleMaps(32.08, 34.78).scheme,
        'comgooglemaps',
      );
      expect(NavigateLinks.waze(32.08, 34.78).scheme, 'waze');
      expect(NavigateLinks.appleMaps(32.08, 34.78).scheme, 'maps');
    });
  });

  group('Slices', () {
    Ticket ticket({
      required DateTime start,
      int duration = 120,
    }) =>
        Ticket(
          key: 'block:1',
          title: 'Late',
          startsAt: start,
          originalStart: start,
          durationMinutes: duration,
          blockId: 1,
        );

    test('a 23:00 event continues at midnight on the next day', () {
      final event = ticket(start: DateTime(2026, 8, 29, 23));
      final monday = Slices.onDay(DateTime(2026, 8, 29), [event]);
      final tuesday = Slices.onDay(DateTime(2026, 8, 30), [event]);

      expect(monday, hasLength(1));
      expect(monday.single.topMinutes, 23 * 60);
      expect(monday.single.durationMinutes, 60);
      expect(monday.single.continuesIntoNext, isTrue);
      expect(monday.single.continuesFromPrevious, isFalse);

      expect(tuesday, hasLength(1));
      expect(tuesday.single.topMinutes, 0);
      expect(tuesday.single.durationMinutes, 60);
      expect(tuesday.single.continuesFromPrevious, isTrue);
      expect(tuesday.single.continuesIntoNext, isFalse);
    });

    test('a ticket that does not reach this day is omitted', () {
      final event = ticket(start: DateTime(2026, 8, 29, 10), duration: 60);
      expect(Slices.onDay(DateTime(2026, 8, 30), [event]), isEmpty);
    });
  });
}
