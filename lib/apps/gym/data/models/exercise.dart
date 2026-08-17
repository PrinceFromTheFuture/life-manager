/// One movement you train.
///
/// Seeded with a starter rack and editable — a fixed enum would mean a
/// migration every time the programme changes.
class Exercise {
  const Exercise({
    this.id,
    required this.name,
    this.onRack = true,
    this.lastWeightG,
    this.lastReps,
    this.sort = 0,
  });

  final int? id;
  final String name;

  /// Whether it appears in the fast picker. The rack is the short list you
  /// work from between sets; everything else stays in the catalogue.
  final bool onRack;

  /// Last logged load, so the recorder can prefill. Grams, never a double.
  final int? lastWeightG;
  final int? lastReps;
  final int sort;

  factory Exercise.fromMap(Map<String, Object?> m) => Exercise(
        id: m['id'] as int?,
        name: m['name']! as String,
        onRack: (m['on_rack'] as int? ?? 1) == 1,
        lastWeightG: m['last_weight_g'] as int?,
        lastReps: m['last_reps'] as int?,
        sort: m['sort']! as int,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'on_rack': onRack ? 1 : 0,
        'last_weight_g': lastWeightG,
        'last_reps': lastReps,
        'sort': sort,
      };

  Exercise copyWith({
    int? id,
    String? name,
    bool? onRack,
    int? lastWeightG,
    int? lastReps,
    int? sort,
  }) =>
      Exercise(
        id: id ?? this.id,
        name: name ?? this.name,
        onRack: onRack ?? this.onRack,
        lastWeightG: lastWeightG ?? this.lastWeightG,
        lastReps: lastReps ?? this.lastReps,
        sort: sort ?? this.sort,
      );

  @override
  bool operator ==(Object other) => other is Exercise && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
