import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/apps/calendar/data/calendar_migrations.dart';
import 'package:shopping_list/apps/calendar/data/calendar_repository.dart';
import 'package:shopping_list/apps/calendar/data/expand/days.dart';
import 'package:shopping_list/apps/calendar/data/expand/overlaps.dart';
import 'package:shopping_list/apps/calendar/data/expand/slices.dart';
import 'package:shopping_list/apps/calendar/data/expand/weekdays.dart';
import 'package:shopping_list/apps/calendar/data/models/block.dart';
import 'package:shopping_list/apps/calendar/data/models/series.dart';
import 'package:shopping_list/apps/calendar/data/models/ticket.dart';
import 'package:shopping_list/apps/calendar/state/providers.dart';
import 'package:shopping_list/apps/calendar/ui/grid/grid_metrics.dart';
import 'package:shopping_list/core/db/database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

DaySlice _slice(String key, int top, int minutes) => DaySlice(
      ticket: Ticket(
        key: key,
        title: key,
        startsAt: DateTime(2026, 10, 6, 0, top),
        originalStart: DateTime(2026, 10, 6, 0, top),
        durationMinutes: minutes,
      ),
      topMinutes: top,
      durationMinutes: minutes,
      continuesFromPrevious: false,
      continuesIntoNext: false,
    );

Map<String, PlacedSlice> _byKey(List<PlacedSlice> placed) =>
    {for (final p in placed) p.slice.ticket.key: p};

void main() {
  group('Overlaps', () {
    test('a lone event takes the whole column', () {
      final placed = Overlaps.place([_slice('a', 600, 60)]);
      expect(placed.single.column, 0);
      expect(placed.single.columns, 1);
    });

    test('two overlapping events split the column', () {
      final placed = _byKey(
        Overlaps.place([_slice('a', 600, 60), _slice('b', 630, 60)]),
      );
      expect(placed['a']!.column, 0);
      expect(placed['b']!.column, 1);
      expect(placed['a']!.columns, 2);
      expect(placed['b']!.columns, 2);
    });

    test('a freed lane is reused inside the same group', () {
      // a: 10:00–12:00 spans b and c; c starts after b ends.
      final placed = _byKey(
        Overlaps.place([
          _slice('a', 600, 120),
          _slice('b', 600, 30),
          _slice('c', 660, 30),
        ]),
      );
      expect(placed['a']!.column, 0);
      expect(placed['b']!.column, 1);
      expect(placed['c']!.column, 1);
      expect(placed.values.every((p) => p.columns == 2), isTrue);
    });

    test('a later event outside the group keeps the full width', () {
      final placed = _byKey(
        Overlaps.place([
          _slice('a', 600, 60),
          _slice('b', 610, 60),
          _slice('c', 900, 30),
        ]),
      );
      expect(placed['c']!.column, 0);
      expect(placed['c']!.columns, 1);
    });

    test('back-to-back events do not overlap', () {
      final placed = Overlaps.place([_slice('a', 600, 60), _slice('b', 660, 60)]);
      expect(placed.every((p) => p.columns == 1), isTrue);
    });

    test('a short event claims its drawn height', () {
      final placed = _byKey(
        Overlaps.place(
          [_slice('a', 600, 5), _slice('b', 610, 30)],
          minMinutes: 15,
        ),
      );
      expect(placed['a']!.columns, 2);
      expect(placed['b']!.column, 1);
    });
  });

  group('Scales', () {
    test('minutes and pixels round-trip', () {
      const scale = TimeScale(72);
      expect(scale.px(60), 72);
      expect(scale.px(90), 108);
      expect(scale.minutes(36), 30);
      expect(scale.dayHeight, 72 * 24);
    });

    test('snapping rounds to the nearest step', () {
      expect(GridMetrics.snap(62, 5), 60);
      expect(GridMetrics.snap(63, 5), 65);
      expect(GridMetrics.snap(7, 15), 0);
      expect(GridMetrics.snap(8, 15), 15);
    });

    test('a column offset stops at the end of the week', () {
      const columns = ColumnScale(viewport: 330, days: 3.3);
      expect(columns.width, closeTo(100, 1e-9));
      expect(columns.maxOffset, closeTo(370, 1e-9));
      expect(columns.offsetFor(2), closeTo(200, 1e-9));
      expect(columns.offsetFor(6), closeTo(370, 1e-9));
    });
  });

  group('Week boundaries', () {
    test('every day of the year lands on a Sunday at midnight', () {
      for (var day = DateTime(2026); day.year == 2026; day = Days.addDays(day, 1)) {
        final start = Days.startOfWeek(day);
        expect(start.weekday, DateTime.sunday, reason: '$day');
        expect(start.hour, 0, reason: '$day');
        expect(Days.between(start, day), inInclusiveRange(0, 6));
        final week = Days.weekOf(day);
        expect(week.every((d) => d.hour == 0 && d.minute == 0), isTrue);
        expect(Days.between(week.first, week.last), 6);
      }
    });

    test('wall-clock minutes survive a clock change', () {
      for (var day = DateTime(2026); day.year == 2026; day = Days.addDays(day, 1)) {
        final at = Days.atMinutes(day, 18 * 60);
        expect(at.hour, 18, reason: '$day');
        expect(Days.isSameDay(at, day), isTrue);
      }
    });

    test('days between ignores the time of day', () {
      expect(Days.between(DateTime(2026, 10, 4, 23), DateTime(2026, 10, 5, 1)), 1);
      expect(Days.between(DateTime(2026, 10, 11), DateTime(2026, 10, 4)), -7);
    });
  });

  group('Undo a move', () {
    late AppDatabase database;
    late CalendarRepository repo;
    late ProviderContainer container;

    setUpAll(sqfliteFfiInit);

    setUp(() async {
      database = await AppDatabase.open(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
        modules: [calendarMigrations],
      );
      repo = CalendarRepository(database);
      container = ProviderContainer(
        overrides: [calendarRepositoryProvider.overrideWithValue(repo)],
      );
    });

    tearDown(() async {
      container.dispose();
      await database.close();
    });

    test('a block goes back to its old time', () async {
      await repo.addBlock(
        Block(
          title: 'Coffee',
          startsAt: DateTime(2026, 10, 6, 9),
          durationMinutes: 30,
          createdAt: DateTime(2026, 10, 1),
        ),
      );
      final before = (await repo.ticketsOnDay(DateTime(2026, 10, 6))).single;
      final controller = container.read(calendarControllerProvider);

      await controller.reschedule(
        before,
        startsAt: DateTime(2026, 10, 7, 14),
        durationMinutes: 45,
      );
      expect(await repo.ticketsOnDay(DateTime(2026, 10, 6)), isEmpty);

      await controller.undoMove(before);
      final after = (await repo.ticketsOnDay(DateTime(2026, 10, 6))).single;
      expect(after.startsAt, DateTime(2026, 10, 6, 9));
      expect(after.durationMinutes, 30);
    });

    test('a plain series occurrence loses the override', () async {
      await repo.addSeries(
        Series(
          title: 'Gym',
          startMinutes: 18 * 60,
          durationMinutes: 60,
          weekdays: Weekdays.tuesday,
          startsOn: DateTime(2026, 9, 1),
          createdAt: DateTime(2026, 9, 1),
        ),
      );
      final before = (await repo.ticketsOnDay(DateTime(2026, 10, 6))).single;
      final controller = container.read(calendarControllerProvider);

      await controller.reschedule(
        before,
        startsAt: DateTime(2026, 10, 6, 20),
        durationMinutes: 60,
      );
      expect(
        (await repo.ticketsOnDay(DateTime(2026, 10, 6))).single.overridden,
        isTrue,
      );

      await controller.undoMove(before);
      final after = (await repo.ticketsOnDay(DateTime(2026, 10, 6))).single;
      expect(after.overridden, isFalse);
      expect(after.startsAt, DateTime(2026, 10, 6, 18));
      expect(await repo.overrides(), isEmpty);
    });

    test('an occurrence that was already moved gets that move back', () async {
      await repo.addSeries(
        Series(
          title: 'Gym',
          startMinutes: 18 * 60,
          durationMinutes: 60,
          weekdays: Weekdays.tuesday,
          startsOn: DateTime(2026, 9, 1),
          createdAt: DateTime(2026, 9, 1),
        ),
      );
      final plain = (await repo.ticketsOnDay(DateTime(2026, 10, 6))).single;
      final controller = container.read(calendarControllerProvider);
      await controller.moveOccurrence(
        plain,
        startsAt: DateTime(2026, 10, 6, 19),
        durationMinutes: 90,
        title: 'Gym with Dan',
      );
      final before = (await repo.ticketsOnDay(DateTime(2026, 10, 6))).single;
      expect(before.title, 'Gym with Dan');

      await controller.reschedule(
        before,
        startsAt: DateTime(2026, 10, 6, 7),
        durationMinutes: 30,
      );
      await controller.undoMove(before);

      final after = (await repo.ticketsOnDay(DateTime(2026, 10, 6))).single;
      expect(after.startsAt, DateTime(2026, 10, 6, 19));
      expect(after.durationMinutes, 90);
      expect(after.title, 'Gym with Dan');
      expect(after.overridden, isTrue);
    });
  });
}
