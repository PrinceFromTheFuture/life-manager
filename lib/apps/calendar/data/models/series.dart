/// How a registered event repeats.
enum SeriesFreq { daily, weekly, monthly }

/// Something that keeps happening — a gym session, a shift, dinner with parents.
class Series {
  const Series({
    this.id,
    required this.title,
    this.locationId,
    required this.startMinutes,
    required this.durationMinutes,
    this.freq = SeriesFreq.weekly,
    this.interval = 1,
    this.weekdays = 0,
    this.monthDay = 1,
    required this.startsOn,
    this.endsOn,
    this.active = true,
    required this.createdAt,
  });

  final int? id;
  final String title;
  final int? locationId;

  /// Minutes from local midnight when each occurrence begins.
  final int startMinutes;
  final int durationMinutes;
  final SeriesFreq freq;

  /// Every N days / weeks / months. Always at least 1.
  final int interval;

  /// Sunday-first bitmask. Only [SeriesFreq.weekly] reads this.
  final int weekdays;

  /// 1–31. Only [SeriesFreq.monthly] reads this.
  final int monthDay;

  final DateTime startsOn;
  final DateTime? endsOn;
  final bool active;
  final DateTime createdAt;

  factory Series.fromMap(Map<String, Object?> m) => Series(
        id: m['id'] as int?,
        title: m['title']! as String,
        locationId: m['location_id'] as int?,
        startMinutes: m['start_minutes']! as int,
        durationMinutes: m['duration_minutes']! as int,
        freq: SeriesFreq.values.firstWhere(
          (f) => f.name == m['freq'],
          orElse: () => SeriesFreq.weekly,
        ),
        interval: m['interval']! as int,
        weekdays: m['weekdays']! as int,
        monthDay: m['month_day']! as int,
        startsOn: DateTime.fromMillisecondsSinceEpoch(m['starts_on']! as int),
        endsOn: m['ends_on'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(m['ends_on']! as int),
        active: (m['active'] as int? ?? 1) == 1,
        createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at']! as int),
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'title': title,
        'location_id': locationId,
        'start_minutes': startMinutes,
        'duration_minutes': durationMinutes,
        'freq': freq.name,
        'interval': interval,
        'weekdays': weekdays,
        'month_day': monthDay,
        'starts_on': startsOn.millisecondsSinceEpoch,
        'ends_on': endsOn?.millisecondsSinceEpoch,
        'active': active ? 1 : 0,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  Series copyWith({
    int? id,
    String? title,
    int? locationId,
    bool clearLocation = false,
    int? startMinutes,
    int? durationMinutes,
    SeriesFreq? freq,
    int? interval,
    int? weekdays,
    int? monthDay,
    DateTime? startsOn,
    DateTime? endsOn,
    bool clearEndsOn = false,
    bool? active,
  }) =>
      Series(
        id: id ?? this.id,
        title: title ?? this.title,
        locationId: clearLocation ? null : (locationId ?? this.locationId),
        startMinutes: startMinutes ?? this.startMinutes,
        durationMinutes: durationMinutes ?? this.durationMinutes,
        freq: freq ?? this.freq,
        interval: interval ?? this.interval,
        weekdays: weekdays ?? this.weekdays,
        monthDay: monthDay ?? this.monthDay,
        startsOn: startsOn ?? this.startsOn,
        endsOn: clearEndsOn ? null : (endsOn ?? this.endsOn),
        active: active ?? this.active,
        createdAt: createdAt,
      );
}
