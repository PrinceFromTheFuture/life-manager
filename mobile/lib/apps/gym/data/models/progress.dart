import 'package:shopping_list/apps/gym/data/models/exercise.dart';

/// This week's training, for the top of the progress screen.
class WeekSummary {
  const WeekSummary({
    required this.weekStart,
    required this.daysTrained,
    required this.trainedDayKeys,
    required this.sets,
    required this.volumeGramReps,
  });

  /// Monday of the week, local midnight.
  final DateTime weekStart;
  final int daysTrained;

  /// `GymActivity.dayKey` for each calendar day that has a set.
  final List<int> trainedDayKeys;
  final int sets;
  final int volumeGramReps;
}

/// One workout's summary for a single movement — the day pass is the session.
class WorkoutMark {
  const WorkoutMark({
    required this.day,
    required this.topWeightG,
    required this.topReps,
    required this.sets,
    required this.volumeGramReps,
  });

  final DateTime day;

  /// Heaviest set that day. Zero is bodyweight.
  final int topWeightG;

  /// Reps on that heaviest set (highest reps if two sets share the load).
  final int topReps;
  final int sets;
  final int volumeGramReps;

  /// Loaded movements plot kilograms. A bodyweight streak plots reps,
  /// otherwise every point would sit on zero.
  static bool plotByReps(List<WorkoutMark> marks) =>
      marks.isNotEmpty && marks.every((m) => m.topWeightG == 0);

  int plotValue({required bool byReps}) => byReps ? topReps : topWeightG;
}

/// What one exercise has done, for the progress list.
class ExerciseProgress {
  const ExerciseProgress({
    required this.exercise,
    this.lastWeightG,
    this.lastReps,
    this.lastAt,
    this.bestWeightG,
    this.bestReps,
    required this.weekVolumeGramReps,
    required this.weekSets,
    required this.recentWorkouts,
    required this.workoutCount,
  });

  final Exercise exercise;
  final int? lastWeightG;
  final int? lastReps;
  final DateTime? lastAt;

  /// Heaviest set ever logged for this movement.
  final int? bestWeightG;

  /// Most reps in a single set — the useful PR when the load is bodyweight.
  final int? bestReps;

  final int weekVolumeGramReps;
  final int weekSets;

  /// Last sessions, oldest first. The list sparkline uses this slice;
  /// the detail screen loads the full history.
  final List<WorkoutMark> recentWorkouts;

  /// How many workouts this movement has, including those off the slice.
  final int workoutCount;
}
