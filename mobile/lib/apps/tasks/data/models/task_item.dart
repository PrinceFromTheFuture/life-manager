/// How soon a task needs a body.
enum TaskUrgency {
  later,
  soon,
  must;

  static TaskUrgency byId(String? id) => switch (id) {
        'must' => TaskUrgency.must,
        'soon' => TaskUrgency.soon,
        _ => TaskUrgency.later,
      };

  String get id => name;
}

/// How a completed occurrence reprints itself.
enum TaskRepeat {
  none,
  daily,
  weekly,
  monthly;

  static TaskRepeat byId(String? id) => switch (id) {
        'daily' => TaskRepeat.daily,
        'weekly' => TaskRepeat.weekly,
        'monthly' => TaskRepeat.monthly,
        _ => TaskRepeat.none,
      };

  String get id => name;
}

/// One piece of work inside a project.
class TaskItem {
  const TaskItem({
    this.id,
    required this.projectId,
    required this.title,
    this.notes,
    this.dueAt,
    this.urgency = TaskUrgency.later,
    this.snoozedUntil,
    this.completedAt,
    this.repeat = TaskRepeat.none,
    required this.createdAt,
    required this.updatedAt,
  });

  final int? id;
  final int projectId;
  final String title;
  final String? notes;
  final DateTime? dueAt;
  final TaskUrgency urgency;
  final DateTime? snoozedUntil;
  final DateTime? completedAt;
  final TaskRepeat repeat;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isDone => completedAt != null;

  bool isSnoozedAt(DateTime now) =>
      snoozedUntil != null && snoozedUntil!.isAfter(now);

  factory TaskItem.fromMap(Map<String, Object?> m) => TaskItem(
        id: m['id'] as int?,
        projectId: m['project_id']! as int,
        title: m['title']! as String,
        notes: m['notes'] as String?,
        dueAt: _millis(m['due_at']),
        urgency: TaskUrgency.byId(m['urgency'] as String?),
        snoozedUntil: _millis(m['snoozed_until']),
        completedAt: _millis(m['completed_at']),
        repeat: TaskRepeat.byId(m['repeat'] as String?),
        createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at']! as int),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(m['updated_at']! as int),
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'project_id': projectId,
        'title': title,
        'notes': notes,
        'due_at': dueAt?.millisecondsSinceEpoch,
        'urgency': urgency.id,
        'snoozed_until': snoozedUntil?.millisecondsSinceEpoch,
        'completed_at': completedAt?.millisecondsSinceEpoch,
        'repeat': repeat.id,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
      };

  TaskItem copyWith({
    int? id,
    int? projectId,
    String? title,
    String? notes,
    bool clearNotes = false,
    DateTime? dueAt,
    bool clearDue = false,
    TaskUrgency? urgency,
    DateTime? snoozedUntil,
    bool clearSnooze = false,
    DateTime? completedAt,
    bool clearCompleted = false,
    TaskRepeat? repeat,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      TaskItem(
        id: id ?? this.id,
        projectId: projectId ?? this.projectId,
        title: title ?? this.title,
        notes: clearNotes ? null : notes ?? this.notes,
        dueAt: clearDue ? null : dueAt ?? this.dueAt,
        urgency: urgency ?? this.urgency,
        snoozedUntil: clearSnooze ? null : snoozedUntil ?? this.snoozedUntil,
        completedAt: clearCompleted ? null : completedAt ?? this.completedAt,
        repeat: repeat ?? this.repeat,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

/// The next due instant after completing an occurrence of [repeat].
DateTime nextDueAfter(DateTime from, TaskRepeat repeat) {
  switch (repeat) {
    case TaskRepeat.none:
      return from;
    case TaskRepeat.daily:
      return from.add(const Duration(days: 1));
    case TaskRepeat.weekly:
      return from.add(const Duration(days: 7));
    case TaskRepeat.monthly:
      final month = from.month + 1;
      final year = month > 12 ? from.year + 1 : from.year;
      final m = month > 12 ? 1 : month;
      final last = DateTime(year, m + 1, 0).day;
      final day = from.day > last ? last : from.day;
      return DateTime(year, m, day, from.hour, from.minute, from.second);
  }
}

DateTime? _millis(Object? value) {
  if (value is! int) return null;
  return DateTime.fromMillisecondsSinceEpoch(value);
}
