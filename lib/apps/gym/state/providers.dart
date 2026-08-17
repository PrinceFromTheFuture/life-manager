import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shopping_list/apps/gym/data/gym_repository.dart';
import 'package:shopping_list/apps/gym/data/models/exercise.dart';
import 'package:shopping_list/apps/gym/data/models/gym_set.dart';
import 'package:shopping_list/apps/gym/data/models/progress.dart';
import 'package:shopping_list/core/activity/providers.dart';
import 'package:shopping_list/core/providers.dart';

final gymRepositoryProvider = Provider<GymRepository>(
  (ref) => GymRepository(ref.watch(databaseProvider)),
);

/// The day pass currently on screen. Always local midnight.
final selectedDayProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

final exercisesProvider = FutureProvider<List<Exercise>>(
  (ref) => ref.watch(gymRepositoryProvider).exercises(),
);

final rackProvider = FutureProvider<List<Exercise>>(
  (ref) => ref.watch(gymRepositoryProvider).rack(),
);

final dayBlocksProvider =
    FutureProvider.autoDispose<List<ExerciseBlock>>((ref) {
  ref.watch(gymTickProvider);
  final day = ref.watch(selectedDayProvider);
  return ref.watch(gymRepositoryProvider).blocksOnDay(day);
});

final dayVolumeProvider = FutureProvider.autoDispose<int>((ref) {
  ref.watch(gymTickProvider);
  final day = ref.watch(selectedDayProvider);
  return ref.watch(gymRepositoryProvider).volumeOnDay(day);
});

final weekSummaryProvider = FutureProvider.autoDispose<WeekSummary>((ref) {
  ref.watch(gymTickProvider);
  return ref.watch(gymRepositoryProvider).weekSummary();
});

final progressProvider =
    FutureProvider.autoDispose<List<ExerciseProgress>>((ref) {
  ref.watch(gymTickProvider);
  return ref.watch(gymRepositoryProvider).progress();
});

/// Bumped after every write so the day pass, progress and hub all refresh
/// without each screen knowing about the others.
final gymTickProvider = StateProvider<int>((ref) => 0);

class GymController {
  GymController(this.ref);

  final Ref ref;

  GymRepository get _repo => ref.read(gymRepositoryProvider);

  void _tick() {
    ref.read(gymTickProvider.notifier).state++;
    ref.invalidate(exercisesProvider);
    ref.invalidate(rackProvider);
    ref.invalidate(activityFeedProvider);
  }

  Future<GymSet> logSet({
    required int exerciseId,
    required int reps,
    required int weightG,
    DateTime? day,
  }) async {
    final DateTime on = day ?? ref.read(selectedDayProvider);
    final saved = await _repo.logSet(
      exerciseId: exerciseId,
      reps: reps,
      weightG: weightG,
      day: on,
    );
    _tick();
    return saved;
  }

  Future<void> deleteSet(int id) async {
    await _repo.deleteSet(id);
    _tick();
  }

  Future<Exercise> addExercise(String name) async {
    final created = await _repo.addExercise(name);
    _tick();
    return created;
  }

  Future<void> renameExercise(int id, String name) async {
    await _repo.renameExercise(id, name);
    _tick();
  }

  Future<void> setOnRack(int id, bool onRack) async {
    await _repo.setOnRack(id, onRack);
    _tick();
  }

  Future<void> reorderExercises(List<int> idsInOrder) async {
    await _repo.reorderExercises(idsInOrder);
    _tick();
  }

  Future<int> exerciseUsage(int id) => _repo.exerciseUsage(id);

  Future<void> deleteExercise(int id) async {
    await _repo.deleteExercise(id);
    _tick();
  }

  Future<int> setsTodayFor(int exerciseId, DateTime day) =>
      _repo.setsTodayFor(exerciseId, day);
}

final gymControllerProvider =
    Provider<GymController>((ref) => GymController(ref));

/// How many sets of this exercise are already on [day]'s pass. Used by the
/// recorder to say "set 3" without a second round-trip after each log.
final setsTodayProvider =
    FutureProvider.autoDispose.family<int, (int, DateTime)>((ref, key) {
  ref.watch(gymTickProvider);
  return ref.watch(gymRepositoryProvider).setsTodayFor(key.$1, key.$2);
});
