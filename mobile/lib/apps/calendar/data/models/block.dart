/// An on-the-fly event. One ticket, no series, no overrides.
class Block {
  const Block({
    this.id,
    required this.title,
    required this.startsAt,
    required this.durationMinutes,
    this.locationId,
    this.note,
    this.inkId,
    this.iconId,
    required this.createdAt,
  });

  final int? id;
  final String title;
  final DateTime startsAt;
  final int durationMinutes;
  final int? locationId;
  final String? note;
  final String? inkId;
  final String? iconId;
  final DateTime createdAt;

  DateTime get endsAt => startsAt.add(Duration(minutes: durationMinutes));

  factory Block.fromMap(Map<String, Object?> m) => Block(
        id: m['id'] as int?,
        title: m['title']! as String,
        startsAt: DateTime.fromMillisecondsSinceEpoch(m['starts_at']! as int),
        durationMinutes: m['duration_minutes']! as int,
        locationId: m['location_id'] as int?,
        note: m['note'] as String?,
        inkId: m['ink_id'] as String?,
        iconId: m['icon_id'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at']! as int),
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'title': title,
        'starts_at': startsAt.millisecondsSinceEpoch,
        'duration_minutes': durationMinutes,
        'location_id': locationId,
        'note': note,
        'ink_id': inkId,
        'icon_id': iconId,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  Block copyWith({
    int? id,
    String? title,
    DateTime? startsAt,
    int? durationMinutes,
    int? locationId,
    bool clearLocation = false,
    String? note,
    bool clearNote = false,
    String? inkId,
    bool clearInk = false,
    String? iconId,
    bool clearIcon = false,
  }) =>
      Block(
        id: id ?? this.id,
        title: title ?? this.title,
        startsAt: startsAt ?? this.startsAt,
        durationMinutes: durationMinutes ?? this.durationMinutes,
        locationId: clearLocation ? null : (locationId ?? this.locationId),
        note: clearNote ? null : (note ?? this.note),
        inkId: clearInk ? null : (inkId ?? this.inkId),
        iconId: clearIcon ? null : (iconId ?? this.iconId),
        createdAt: createdAt,
      );
}
