/// A visible blotter ticket — a fly block, or one expanded occurrence.
class Ticket {
  const Ticket({
    required this.key,
    required this.title,
    required this.startsAt,
    required this.originalStart,
    required this.durationMinutes,
    this.locationId,
    this.note,
    this.inkId,
    this.iconId,
    this.seriesId,
    this.blockId,
    this.overridden = false,
  });

  /// Stable for this visible row: `block:12` or `series:3:millis`.
  final String key;
  final String title;
  final DateTime startsAt;
  final DateTime originalStart;
  final int durationMinutes;
  final int? locationId;
  final String? note;
  final String? inkId;
  final String? iconId;
  final int? seriesId;
  final int? blockId;
  final bool overridden;

  bool get fromRegistry => seriesId != null;

  DateTime get endsAt => startsAt.add(Duration(minutes: durationMinutes));

  Ticket copyWith({
    DateTime? startsAt,
    int? durationMinutes,
    int? locationId,
    String? title,
    String? note,
    String? inkId,
    String? iconId,
    bool? overridden,
  }) =>
      Ticket(
        key: key,
        title: title ?? this.title,
        startsAt: startsAt ?? this.startsAt,
        originalStart: originalStart,
        durationMinutes: durationMinutes ?? this.durationMinutes,
        locationId: locationId ?? this.locationId,
        note: note ?? this.note,
        inkId: inkId ?? this.inkId,
        iconId: iconId ?? this.iconId,
        seriesId: seriesId,
        blockId: blockId,
        overridden: overridden ?? this.overridden,
      );
}
