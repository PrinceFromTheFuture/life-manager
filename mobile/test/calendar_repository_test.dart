import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/apps/calendar/data/calendar_activity.dart';
import 'package:shopping_list/apps/calendar/data/calendar_migrations.dart';
import 'package:shopping_list/apps/calendar/data/calendar_repository.dart';
import 'package:shopping_list/apps/calendar/data/expand/weekdays.dart';
import 'package:shopping_list/apps/calendar/data/models/block.dart';
import 'package:shopping_list/apps/calendar/data/models/series.dart';
import 'package:shopping_list/core/activity/activity_dao.dart';
import 'package:shopping_list/core/db/database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late AppDatabase database;
  late CalendarRepository repo;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    database = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
      modules: [calendarMigrations],
    );
    repo = CalendarRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('a fly event writes one block and a feed row', () async {
    final saved = await repo.addBlock(
      Block(
        title: 'Coffee',
        startsAt: DateTime(2026, 8, 29, 10),
        durationMinutes: 30,
        createdAt: DateTime(2026, 8, 29),
      ),
    );
    expect(saved.id, isNotNull);

    final tickets = await repo.ticketsOnDay(DateTime(2026, 8, 29));
    expect(tickets.single.title, 'Coffee');
    expect(tickets.single.blockId, saved.id);

    final entries = await ActivityDao(database.db).recent();
    expect(entries.single.appId, CalendarActivity.appId);
    expect(entries.single.kind, CalendarActivity.blockAdded);
  });

  test('dragging a registry ticket writes a this-time override', () async {
    final series = await repo.addSeries(
      Series(
        title: 'Gym',
        startMinutes: 18 * 60,
        durationMinutes: 60,
        freq: SeriesFreq.weekly,
        weekdays: Weekdays.saturday,
        startsOn: DateTime(2026, 8, 1),
        createdAt: DateTime(2026, 8, 1),
      ),
    );

    final day = DateTime(2026, 8, 29);
    final before = await repo.ticketsOnDay(day);
    expect(before, hasLength(1));
    expect(before.single.startsAt.hour, 18);

    await repo.reschedule(
      before.single,
      startsAt: DateTime(2026, 8, 29, 20),
      durationMinutes: 45,
    );

    final after = await repo.ticketsOnDay(day);
    expect(after.single.startsAt, DateTime(2026, 8, 29, 20));
    expect(after.single.durationMinutes, 45);
    expect(after.single.overridden, isTrue);
    expect(after.single.originalStart, DateTime(2026, 8, 29, 18));
    expect(after.single.seriesId, series.id);
  });

  test('skipping a registry ticket hides it from today', () async {
    await repo.addSeries(
      Series(
        title: 'Dinner',
        startMinutes: 19 * 60,
        durationMinutes: 90,
        freq: SeriesFreq.weekly,
        weekdays: Weekdays.saturday,
        startsOn: DateTime(2026, 8, 1),
        createdAt: DateTime(2026, 8, 1),
      ),
    );
    final ticket = (await repo.ticketsOnDay(DateTime(2026, 8, 29))).single;
    await repo.skipOccurrence(
      seriesId: ticket.seriesId!,
      originalStart: ticket.originalStart,
    );

    expect(await repo.ticketsOnDay(DateTime(2026, 8, 29)), isEmpty);
    expect(
      await repo.today(now: DateTime(2026, 8, 29, 12)),
      isEmpty,
    );
  });
}
