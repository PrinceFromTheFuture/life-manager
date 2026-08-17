import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/apps/gym/data/gym_activity.dart';
import 'package:shopping_list/apps/gym/data/gym_migrations.dart';
import 'package:shopping_list/apps/gym/data/gym_repository.dart';
import 'package:shopping_list/core/activity/activity_dao.dart';
import 'package:shopping_list/core/db/database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late AppDatabase database;
  late GymRepository repo;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    database = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
      modules: [gymMigrations],
    );
    repo = GymRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  group('seeds', () {
    test('a starter rack is ready to log against', () async {
      final rack = await repo.rack();
      expect(rack, isNotEmpty);
      expect(rack.map((e) => e.name), contains('Squat'));
      expect(rack.every((e) => e.onRack), isTrue);
    });

    test('re-running the migration does not duplicate them', () async {
      final before = (await repo.exercises()).length;
      for (final statement in gymMigrations.migrations.first.statements) {
        await database.db.execute(statement);
      }
      expect((await repo.exercises()).length, before);
    });
  });

  group('logging a set', () {
    test('writes exactly one feed entry for the day, then updates it',
        () async {
      final squat =
          (await repo.exercises()).firstWhere((e) => e.name == 'Squat');
      final day = DateTime(2026, 8, 13);

      await repo.logSet(
        exerciseId: squat.id!,
        reps: 8,
        weightG: 80000,
        day: day,
      );

      var entries = await ActivityDao(database.db).recent();
      expect(entries, hasLength(1));
      expect(entries.single.appId, GymActivity.appId);
      expect(entries.single.kind, GymActivity.dayPass);
      expect(entries.single.amountMinor, isNull);
      expect(entries.single.refId, GymActivity.dayKey(day));
      expect(entries.single.subtitle, contains('1 set'));
      expect(entries.single.subtitle, contains('Squat'));

      await repo.logSet(
        exerciseId: squat.id!,
        reps: 8,
        weightG: 80000,
        day: day,
      );

      entries = await ActivityDao(database.db).recent();
      expect(entries, hasLength(1));
      expect(entries.single.subtitle, contains('2 sets'));
    });

    test('remembers the last load so the recorder can prefill', () async {
      final squat =
          (await repo.exercises()).firstWhere((e) => e.name == 'Squat');
      await repo.logSet(
        exerciseId: squat.id!,
        reps: 5,
        weightG: 100000,
        day: DateTime(2026, 8, 13),
      );

      final updated = await repo.exercise(squat.id!);
      expect(updated!.lastWeightG, 100000);
      expect(updated.lastReps, 5);
    });

    test('groups sets onto the day pass in log order', () async {
      final all = await repo.exercises();
      final squat = all.firstWhere((e) => e.name == 'Squat');
      final bench = all.firstWhere((e) => e.name == 'Bench press');
      final day = DateTime(2026, 8, 13);

      await repo.logSet(
        exerciseId: squat.id!,
        reps: 8,
        weightG: 80000,
        day: day,
      );
      await repo.logSet(
        exerciseId: bench.id!,
        reps: 8,
        weightG: 60000,
        day: day,
      );
      await repo.logSet(
        exerciseId: squat.id!,
        reps: 6,
        weightG: 82500,
        day: day,
      );

      final blocks = await repo.blocksOnDay(day);
      expect(blocks, hasLength(2));
      expect(blocks[0].name, 'Squat');
      expect(blocks[0].sets, hasLength(2));
      expect(blocks[1].name, 'Bench press');
      expect(blocks[1].sets, hasLength(1));
      expect(await repo.volumeOnDay(day), 80000 * 8 + 60000 * 8 + 82500 * 6);
    });

    test('deleting the last set of the day removes the feed row', () async {
      final squat =
          (await repo.exercises()).firstWhere((e) => e.name == 'Squat');
      final day = DateTime(2026, 8, 13);
      final saved = await repo.logSet(
        exerciseId: squat.id!,
        reps: 8,
        weightG: 80000,
        day: day,
      );

      expect(await ActivityDao(database.db).recent(), hasLength(1));
      await repo.deleteSet(saved.id!);
      expect(await ActivityDao(database.db).recent(), isEmpty);
      expect(await repo.blocksOnDay(day), isEmpty);
    });
  });

  group('progress', () {
    test('records a PR and this week volume per exercise', () async {
      final squat =
          (await repo.exercises()).firstWhere((e) => e.name == 'Squat');
      final day = DateTime(2026, 8, 13);

      await repo.logSet(
        exerciseId: squat.id!,
        reps: 8,
        weightG: 80000,
        day: day,
      );
      await repo.logSet(
        exerciseId: squat.id!,
        reps: 3,
        weightG: 100000,
        day: day,
      );

      final progress = await repo.progress(day);
      final row = progress.firstWhere((p) => p.exercise.name == 'Squat');
      expect(row.bestWeightG, 100000);
      expect(row.lastWeightG, 100000);
      expect(row.lastReps, 3);
      expect(row.weekSets, 2);
      expect(row.weekVolumeGramReps, 80000 * 8 + 100000 * 3);
      expect(row.recentTopWeights, [100000]);
    });

    test('week summary counts local days, not UTC buckets', () async {
      final squat =
          (await repo.exercises()).firstWhere((e) => e.name == 'Squat');
      await repo.logSet(
        exerciseId: squat.id!,
        reps: 5,
        weightG: 80000,
        day: DateTime(2026, 8, 10),
      );
      await repo.logSet(
        exerciseId: squat.id!,
        reps: 5,
        weightG: 80000,
        day: DateTime(2026, 8, 13),
      );

      final week = await repo.weekSummary(DateTime(2026, 8, 13));
      expect(week.daysTrained, 2);
      expect(week.sets, 2);
    });
  });

  group('the rack', () {
    test('taking an exercise off the rack hides it from the picker', () async {
      final plank =
          (await repo.exercises()).firstWhere((e) => e.name == 'Plank');
      expect(plank.onRack, isFalse);
      expect(
        (await repo.rack()).map((e) => e.name),
        isNot(contains('Plank')),
      );

      await repo.setOnRack(plank.id!, true);
      expect(
        (await repo.rack()).map((e) => e.name),
        contains('Plank'),
      );
    });
  });
}
