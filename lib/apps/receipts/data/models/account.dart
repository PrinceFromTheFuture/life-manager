/// What you paid with.
class Account {
  const Account({
    this.id,
    required this.name,
    this.kind = 'other',
    this.last4,
    this.sort = 0,
  });

  final int? id;
  final String name;

  /// `cash`, `card`, `bank`, `other`. A plain string rather than an enum so
  /// adding a kind never needs a migration.
  final String kind;

  /// Last four digits, when it helps tell two cards apart.
  final String? last4;

  final int sort;

  /// What the chip shows: `Visa ·1234` reads better than either half alone.
  String get label => last4 == null || last4!.isEmpty ? name : '$name ·$last4';

  factory Account.fromMap(Map<String, Object?> m) => Account(
        id: m['id'] as int?,
        name: m['name']! as String,
        kind: (m['kind'] as String?) ?? 'other',
        last4: m['last4'] as String?,
        sort: m['sort']! as int,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'kind': kind,
        'last4': last4,
        'sort': sort,
      };

  @override
  bool operator ==(Object other) => other is Account && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
