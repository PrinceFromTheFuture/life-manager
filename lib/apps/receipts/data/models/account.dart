/// Where money actually sits.
///
/// Distinct from a payment method, which is a way of reaching an account. The
/// balance is never stored here: it is derived from [openingMinor] plus every
/// entry in the append-only ledger, so it cannot drift out of step with the
/// history that explains it.
class Account {
  const Account({
    this.id,
    required this.name,
    this.kind = 'other',
    this.last4,
    this.sort = 0,
    this.openingMinor = 0,
    this.openedAt,
    this.archivedAt,
  });

  final int? id;
  final String name;

  /// `cash`, `card`, `bank`, `other`. A plain string rather than an enum so
  /// adding a kind never needs a migration.
  final String kind;

  /// Last four digits, when it helps tell two cards apart.
  final String? last4;

  final int sort;

  /// What the account held on the day you started tracking it. Without this
  /// the derived balance would only be correct for an account whose ledger
  /// reaches back to the day it was opened, which no real account's does.
  final int openingMinor;

  final DateTime? openedAt;

  /// Archived rather than deleted: a closed account still owns its history.
  final DateTime? archivedAt;

  bool get isArchived => archivedAt != null;

  /// What the chip shows: `Visa ·1234` reads better than either half alone.
  String get label => last4 == null || last4!.isEmpty ? name : '$name ·$last4';

  factory Account.fromMap(Map<String, Object?> m) => Account(
        id: m['id'] as int?,
        name: m['name']! as String,
        kind: (m['kind'] as String?) ?? 'other',
        last4: m['last4'] as String?,
        sort: m['sort']! as int,
        openingMinor: (m['opening_minor'] as int?) ?? 0,
        openedAt: m['opened_at'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(m['opened_at']! as int),
        archivedAt: m['archived_at'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(m['archived_at']! as int),
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'kind': kind,
        'last4': last4,
        'sort': sort,
        'opening_minor': openingMinor,
        'opened_at': openedAt?.millisecondsSinceEpoch,
        'archived_at': archivedAt?.millisecondsSinceEpoch,
      };

  Account copyWith({
    int? id,
    String? name,
    String? kind,
    String? last4,
    int? sort,
    int? openingMinor,
    DateTime? openedAt,
    DateTime? archivedAt,
  }) =>
      Account(
        id: id ?? this.id,
        name: name ?? this.name,
        kind: kind ?? this.kind,
        last4: last4 ?? this.last4,
        sort: sort ?? this.sort,
        openingMinor: openingMinor ?? this.openingMinor,
        openedAt: openedAt ?? this.openedAt,
        archivedAt: archivedAt ?? this.archivedAt,
      );

  @override
  bool operator ==(Object other) => other is Account && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
