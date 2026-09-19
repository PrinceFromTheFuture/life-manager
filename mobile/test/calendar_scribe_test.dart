import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shopping_list/apps/calendar/data/ai/calendar_apply.dart';
import 'package:shopping_list/apps/calendar/data/ai/calendar_plan.dart';
import 'package:shopping_list/apps/calendar/data/ai/calendar_scribe.dart';
import 'package:shopping_list/apps/calendar/data/calendar_migrations.dart';
import 'package:shopping_list/apps/calendar/data/calendar_repository.dart';
import 'package:shopping_list/apps/calendar/data/expand/weekdays.dart';
import 'package:shopping_list/apps/calendar/data/models/series.dart';
import 'package:shopping_list/core/db/database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CalendarScribe.parsePlan', () {
    test('reads a create with local times', () {
      final plan = CalendarScribe.parsePlan({
        'edits': [
          {
            'op': 'create',
            'ticket_key': null,
            'title': 'Coffee',
            'starts_at': '2026-08-29T08:00',
            'ends_at': '2026-08-29T08:30',
            'location': 'Home',
            'note': 'Takeaway',
            'ink': 'teal',
            'icon': 'cup',
          },
        ],
      });
      expect(plan.edits, hasLength(1));
      expect(plan.edits.single.op, CalendarOp.create);
      expect(plan.edits.single.title, 'Coffee');
      expect(plan.edits.single.startsAt, DateTime(2026, 8, 29, 8));
      expect(plan.edits.single.durationMinutes(), 30);
      expect(plan.edits.single.ink, 'teal');
      expect(plan.edits.single.icon, 'cup');
    });

    test('drops an invented ink and an empty ticket key', () {
      final plan = CalendarScribe.parsePlan({
        'edits': [
          {
            'op': 'adjust',
            'ticket_key': '  ',
            'title': 'Gym',
            'starts_at': null,
            'ends_at': null,
            'location': null,
            'note': null,
            'ink': 'hotpink',
            'icon': null,
          },
        ],
      });
      expect(plan.edits.single.ticketKey, isNull);
      expect(plan.edits.single.ink, isNull);
    });

    test('the schema has no series fields', () {
      final properties = CalendarScribe.schema['properties'] as Map;
      expect(properties.keys, ['edits']);
      final item = (properties['edits'] as Map)['items'] as Map;
      final keys = (item['properties'] as Map).keys;
      expect(keys, isNot(contains('freq')));
      expect(keys, isNot(contains('weekdays')));
      expect(keys, isNot(contains('interval')));
    });

    test('parseReply splits prose from a calendar-edit fence', () {
      const raw = '''
Moved gym.

```calendar-edit
{"edits":[{"op":"adjust","ticket_key":"series:1:1","title":"Gym","starts_at":"2026-08-29T19:00","ends_at":"2026-08-29T20:00","location":null,"note":null,"ink":null,"icon":null}]}
```
''';
      final reply = CalendarScribe.parseReply(raw);
      expect(reply.text, 'Moved gym.');
      expect(reply.plan.edits, hasLength(1));
      expect(reply.plan.edits.single.op, CalendarOp.adjust);
      expect(reply.plan.edits.single.startsAt, DateTime(2026, 8, 29, 19));
    });
  });

  group('CalendarScribe.plan', () {
    test('asks for the calendar schema, never a series', () async {
      late Map<String, Object?> body;
      final scribe = CalendarScribe(
        'test-key',
        client: MockClient((request) async {
          body = jsonDecode(request.body) as Map<String, Object?>;
          return http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {
                    'content': jsonEncode({
                      'edits': [
                        {
                          'op': 'create',
                          'ticket_key': null,
                          'title': 'Walk',
                          'starts_at': '2026-08-29T07:00',
                          'ends_at': '2026-08-29T07:30',
                          'location': null,
                          'note': null,
                          'ink': null,
                          'icon': null,
                        },
                      ],
                    }),
                  },
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final plan = await scribe.plan(
        request: 'Add a walk at 7',
        now: DateTime(2026, 8, 29, 12),
        day: DateTime(2026, 8, 29),
        places: const [],
        tickets: const [],
      );
      expect(plan.edits.single.title, 'Walk');
      final schema = ((body['response_format'] as Map)['json_schema']
          as Map)['schema'] as Map;
      expect((schema['properties'] as Map).keys, ['edits']);
      final prompt = (body['messages'] as List).first as Map;
      expect(prompt['content'], contains('MUST NOT'));
      expect(prompt['content'], contains('registry'));
    });
  });

  group('CalendarApply', () {
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

    test('create writes a block, never a series', () async {
      await repo.addPlace(
        title: 'Home',
        latitude: 32.08,
        longitude: 34.78,
        inkId: 'teal',
        iconId: 'home',
      );
      final places = await repo.places();

      final result = await CalendarApply(repo).run(
        CalendarPlan(
          edits: [
            CalendarEdit(
              op: CalendarOp.create,
              title: 'Coffee',
              startsAt: DateTime(2026, 8, 29, 8),
              endsAt: DateTime(2026, 8, 29, 8, 30),
              location: 'home',
              note: 'Takeaway',
              ink: 'teal',
              icon: 'cup',
            ),
          ],
        ),
        places: places,
        tickets: const [],
      );

      expect(result.created, 1);
      expect(await repo.series(), isEmpty);
      final tickets = await repo.ticketsOnDay(DateTime(2026, 8, 29));
      expect(tickets.single.title, 'Coffee');
      expect(tickets.single.blockId, isNotNull);
      expect(tickets.single.seriesId, isNull);
      expect(tickets.single.note, 'Takeaway');
      expect(tickets.single.inkId, 'teal');
      expect(tickets.single.locationId, places.single.id);
    });

    test('adjust on a series ticket writes an override, not the series', () async {
      await repo.addSeries(
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
      final before = (await repo.ticketsOnDay(DateTime(2026, 8, 29))).single;
      final seriesBefore = (await repo.series()).single;

      await CalendarApply(repo).run(
        CalendarPlan(
          edits: [
            CalendarEdit(
              op: CalendarOp.adjust,
              ticketKey: before.key,
              startsAt: DateTime(2026, 8, 29, 20),
              endsAt: DateTime(2026, 8, 29, 21),
              title: 'Gym — late',
            ),
          ],
        ),
        places: const [],
        tickets: [before],
      );

      final after = (await repo.ticketsOnDay(DateTime(2026, 8, 29))).single;
      expect(after.startsAt, DateTime(2026, 8, 29, 20));
      expect(after.title, 'Gym — late');
      expect(after.overridden, isTrue);
      final seriesAfter = (await repo.series()).single;
      expect(seriesAfter.startMinutes, seriesBefore.startMinutes);
      expect(seriesAfter.title, 'Gym');
      expect(seriesAfter.freq, SeriesFreq.weekly);
    });

    test('cancel skips a series ticket and ignores an unknown place', () async {
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

      final result = await CalendarApply(repo).run(
        CalendarPlan(
          edits: [
            CalendarEdit(
              op: CalendarOp.cancel,
              ticketKey: ticket.key,
            ),
            CalendarEdit(
              op: CalendarOp.create,
              title: 'Errand',
              startsAt: DateTime(2026, 8, 29, 10),
              endsAt: DateTime(2026, 8, 29, 10, 30),
              location: 'A place that does not exist',
            ),
          ],
        ),
        places: const [],
        tickets: [ticket],
      );

      expect(result.cancelled, 1);
      expect(result.created, 1);
      expect(await repo.ticketsOnDay(DateTime(2026, 8, 29)), hasLength(1));
      expect(
        (await repo.ticketsOnDay(DateTime(2026, 8, 29))).single.locationId,
        isNull,
      );
      expect(await repo.series(), hasLength(1));
    });
  });
}
