/// One set on a day pass.
///
/// The day *is* the session — there is no separate session row. [occurredAt]
/// falling on a calendar day is what groups sets onto that pass.
class GymSet {
  const GymSet({
    this.id,
    required this.exerciseId,
    required this.occurredAt,
    required this.reps,
    required this.weightG,
    required this.createdAt,
    this.exerciseName,
  });

  final int? id;
  final int exerciseId;
  final DateTime occurredAt;

  /// How many times the load moved. Integer, always.
  final int reps;

  /// Grams. Zero means bodyweight.
  final int weightG;
  final DateTime createdAt;

  /// Joined in when listing a day, so the pass can group without a second
  /// lookup. Null on a write.
  final String? exerciseName;

  int get volumeGramReps => weightG * reps;

  factory GymSet.fromMap(Map<String, Object?> m) => GymSet(
        id: m['id'] as int?,
        exerciseId: m['exercise_id']! as int,
        occurredAt:
            DateTime.fromMillisecondsSinceEpoch(m['occurred_at']! as int),
        reps: m['reps']! as int,
        weightG: m['weight_g']! as int,
        createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at']! as int),
        exerciseName: m['exercise_name'] as String?,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'exercise_id': exerciseId,
        'occurred_at': occurredAt.millisecondsSinceEpoch,
        'reps': reps,
        'weight_g': weightG,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  @override
  bool operator ==(Object other) => other is GymSet && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Sets for one exercise on one day, in the order they were logged.
class ExerciseBlock {
  const ExerciseBlock(
      {required this.exerciseId, required this.name, required this.sets});

  final int exerciseId;
  final String name;
  final List<GymSet> sets;
}
