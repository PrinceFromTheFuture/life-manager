/// A single line on a shopping list.
class TripItem {
  const TripItem({
    this.id,
    required this.tripId,
    this.productId,
    required this.nameSnapshot,
    this.quantity = 1,
    this.unit,
    this.isPicked = false,
    this.pickedAt,
    this.sortOrder = 0,
    this.priceMinor,
  });

  final int? id;
  final int tripId;

  /// The catalogue entry this came from. Nullable, and intentionally set to
  /// null rather than cascading if that product is ever deleted.
  final int? productId;

  /// The name as it was when the item was added.
  ///
  /// History has to stay truthful: renaming "Milk" to "Oat milk" next month
  /// must not rewrite what last month's receipt says was bought.
  final String nameSnapshot;

  /// Real-valued so `1.5 kg` is expressible. Unlike money, a fractional
  /// quantity has no exactness requirement.
  final double quantity;

  final String? unit;
  final bool isPicked;
  final DateTime? pickedAt;
  final int sortOrder;

  /// Per-item price in agorot. Optional — the brief only requires a trip total,
  /// but the column exists so per-item pricing can be added without a
  /// migration.
  final int? priceMinor;

  /// Quantity without a pointless trailing `.0`: `2`, `1.5`, `0.25`.
  String get quantityLabel {
    if (quantity == quantity.roundToDouble()) {
      return quantity.round().toString();
    }
    return quantity
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  /// What the row shows on the right: `2 ×` or `1.5 kg`.
  String get measureLabel =>
      unit == null || unit!.isEmpty ? '$quantityLabel ×' : '$quantityLabel $unit';

  factory TripItem.fromMap(Map<String, Object?> m) => TripItem(
        id: m['id'] as int?,
        tripId: m['trip_id']! as int,
        productId: m['product_id'] as int?,
        nameSnapshot: m['name_snapshot']! as String,
        quantity: (m['quantity']! as num).toDouble(),
        unit: m['unit'] as String?,
        isPicked: (m['is_picked']! as int) == 1,
        pickedAt: m['picked_at'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(m['picked_at']! as int),
        sortOrder: m['sort_order']! as int,
        priceMinor: m['price_minor'] as int?,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'trip_id': tripId,
        'product_id': productId,
        'name_snapshot': nameSnapshot,
        'quantity': quantity,
        'unit': unit,
        'is_picked': isPicked ? 1 : 0,
        'picked_at': pickedAt?.millisecondsSinceEpoch,
        'sort_order': sortOrder,
        'price_minor': priceMinor,
      };

  TripItem copyWith({
    int? id,
    double? quantity,
    String? unit,
    bool? isPicked,
    DateTime? pickedAt,
    int? sortOrder,
    int? priceMinor,
    bool clearPickedAt = false,
  }) =>
      TripItem(
        id: id ?? this.id,
        tripId: tripId,
        productId: productId,
        nameSnapshot: nameSnapshot,
        quantity: quantity ?? this.quantity,
        unit: unit ?? this.unit,
        isPicked: isPicked ?? this.isPicked,
        pickedAt: clearPickedAt ? null : (pickedAt ?? this.pickedAt),
        sortOrder: sortOrder ?? this.sortOrder,
        priceMinor: priceMinor ?? this.priceMinor,
      );

  @override
  bool operator ==(Object other) => other is TripItem && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
