import 'package:shopping_list/apps/gym/data/models/exercise.dart';

/// This week's training, for the top of the progress screen.
class WeekSummary {
  const WeekSummary({
    required this.daysTrained,
    required this.sets,
    required this.volumeGramReps,
  });

  final int daysTrained;
  final int sets;
  final int volumeGramReps;
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
    required this.recentTopWeights,
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

  /// Heaviest set from each of the last sessions, oldest first. Empty until
  /// there is history. Used as a paper sparkline, not a chart.
  final List<int> recentTopWeights;
}
