/// What happened to one occurrence of a series.
enum OverrideKind { skip, move }

/// A this-time-only correction, keyed by the occurrence the series would have
/// written. Dragging a registry ticket writes one of these.
class OccurrenceOverride {
  const OccurrenceOverride({
    this.id,
    required this.seriesId,
    required this.originalStart,
    required this.kind,
    this.startsAt,
    this.durationMinutes,
    this.locationId,
    this.title,
    this.note,
    this.inkId,
    this.iconId,
    required this.createdAt,
  });

  final int? id;
  final int seriesId;
  final DateTime originalStart;
  final OverrideKind kind;
  final DateTime? startsAt;
  final int? durationMinutes;
  final int? locationId;
  final String? title;
  final String? note;
  final String? inkId;
  final String? iconId;
  final DateTime createdAt;

  factory OccurrenceOverride.fromMap(Map<String, Object?> m) =>
      OccurrenceOverride(
        id: m['id'] as int?,
        seriesId: m['series_id']! as int,
        originalStart:
            DateTime.fromMillisecondsSinceEpoch(m['original_start']! as int),
        kind: (m['kind'] as String?) == 'skip'
            ? OverrideKind.skip
            : OverrideKind.move,
        startsAt: m['starts_at'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(m['starts_at']! as int),
        durationMinutes: m['duration_minutes'] as int?,
        locationId: m['location_id'] as int?,
        title: m['title'] as String?,
        note: m['note'] as String?,
        inkId: m['ink_id'] as String?,
        iconId: m['icon_id'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at']! as int),
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'series_id': seriesId,
        'original_start': originalStart.millisecondsSinceEpoch,
        'kind': kind.name,
        'starts_at': startsAt?.millisecondsSinceEpoch,
        'duration_minutes': durationMinutes,
        'location_id': locationId,
        'title': title,
        'note': note,
        'ink_id': inkId,
        'icon_id': iconId,
        'created_at': createdAt.millisecondsSinceEpoch,
      };
}
