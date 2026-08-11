import '../../util/normalize.dart';

/// A product the user has bought before. This is the catalogue that powers
/// autocomplete — it grows on its own as they shop, and is never edited
/// directly.
class Product {
  const Product({
    this.id,
    required this.name,
    required this.nameNormalized,
    this.defaultUnit,
    this.usageCount = 0,
    this.lastUsedAt,
    required this.createdAt,
  });

  final int? id;
  final String name;

  /// Deduplication and search key. See [normalizeName]. Unique in the table.
  final String nameNormalized;

  final String? defaultUnit;

  /// How many times this has been added to a list. Ranks autocomplete, so the
  /// things actually bought every week surface first.
  final int usageCount;

  final DateTime? lastUsedAt;
  final DateTime createdAt;

  factory Product.create(String rawName, {String? unit}) {
    final clean = cleanName(rawName);
    return Product(
      name: clean,
      nameNormalized: normalizeName(clean),
      defaultUnit: unit,
      createdAt: DateTime.now(),
    );
  }

  factory Product.fromMap(Map<String, Object?> m) => Product(
        id: m['id'] as int?,
        name: m['name']! as String,
        nameNormalized: m['name_normalized']! as String,
        defaultUnit: m['default_unit'] as String?,
        usageCount: m['usage_count']! as int,
        lastUsedAt: m['last_used_at'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(m['last_used_at']! as int),
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(m['created_at']! as int),
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'name_normalized': nameNormalized,
        'default_unit': defaultUnit,
        'usage_count': usageCount,
        'last_used_at': lastUsedAt?.millisecondsSinceEpoch,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  Product copyWith({
    int? id,
    String? name,
    String? nameNormalized,
    String? defaultUnit,
    int? usageCount,
    DateTime? lastUsedAt,
  }) =>
      Product(
        id: id ?? this.id,
        name: name ?? this.name,
        nameNormalized: nameNormalized ?? this.nameNormalized,
        defaultUnit: defaultUnit ?? this.defaultUnit,
        usageCount: usageCount ?? this.usageCount,
        lastUsedAt: lastUsedAt ?? this.lastUsedAt,
        createdAt: createdAt,
      );

  @override
  bool operator ==(Object other) =>
      other is Product && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);
}
