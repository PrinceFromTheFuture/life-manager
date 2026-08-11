import 'package:shopping_list/core/util/money.dart';

enum TripStatus { active, completed }

/// One shopping trip.
///
/// The main shopping list *is* the active trip — there is no separate "current
/// list" entity. At most one trip may be [TripStatus.active] at a time, an
/// invariant the repository enforces.
class Trip {
  const Trip({
    this.id,
    required this.status,
    required this.startedAt,
    this.completedAt,
    this.totalMinor,
    this.currency = Money.currencyCode,
    this.receiptPath,
    this.note,
  });

  final int? id;
  final TripStatus status;
  final DateTime startedAt;
  final DateTime? completedAt;

  /// The total in agorot. Null until checkout. Never a double — see [Money].
  final int? totalMinor;

  final String currency;

  /// Path to the receipt image *relative to the app documents directory*.
  ///
  /// Storing an absolute path here is the single most likely way to break this
  /// app: the OS reassigns the container directory between installs and
  /// upgrades, so yesterday's absolute path silently stops resolving.
  final String? receiptPath;

  final String? note;

  bool get isActive => status == TripStatus.active;

  factory Trip.start() => Trip(
        status: TripStatus.active,
        startedAt: DateTime.now(),
      );

  factory Trip.fromMap(Map<String, Object?> m) => Trip(
        id: m['id'] as int?,
        status: (m['status']! as String) == 'active'
            ? TripStatus.active
            : TripStatus.completed,
        startedAt:
            DateTime.fromMillisecondsSinceEpoch(m['started_at']! as int),
        completedAt: m['completed_at'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(m['completed_at']! as int),
        totalMinor: m['total_minor'] as int?,
        currency: (m['currency'] as String?) ?? Money.currencyCode,
        receiptPath: m['receipt_path'] as String?,
        note: m['note'] as String?,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'status': status.name,
        'started_at': startedAt.millisecondsSinceEpoch,
        'completed_at': completedAt?.millisecondsSinceEpoch,
        'total_minor': totalMinor,
        'currency': currency,
        'receipt_path': receiptPath,
        'note': note,
      };

  Trip copyWith({
    int? id,
    TripStatus? status,
    DateTime? completedAt,
    int? totalMinor,
    String? receiptPath,
    String? note,
    bool clearReceipt = false,
  }) =>
      Trip(
        id: id ?? this.id,
        status: status ?? this.status,
        startedAt: startedAt,
        completedAt: completedAt ?? this.completedAt,
        totalMinor: totalMinor ?? this.totalMinor,
        currency: currency,
        receiptPath: clearReceipt ? null : (receiptPath ?? this.receiptPath),
        note: note ?? this.note,
      );
}

/// A completed trip plus the counts the history list needs, assembled in one
/// query so the list doesn't fire N follow-ups while scrolling.
class TripSummary {
  const TripSummary({
    required this.trip,
    required this.itemCount,
    required this.pickedCount,
  });

  final Trip trip;
  final int itemCount;
  final int pickedCount;
}
