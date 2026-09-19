/// Implicit supermarket layout, learned from the order things are picked.
///
/// Each completed shop is a walk through the store. The first tick is the
/// first aisle they hit; the last is the last. Averaging those walks — with
/// recent shops counting for more — produces a rank per product. Pick-up
/// Mode sorts by that rank so the list reads in store order without anyone
/// having to teach it, name it, or turn it on.
///
/// Confined to groceries. The planning list stays in add order; only the
/// aisle-facing screen is rearranged, and only using shops that have
/// already been checked out, so a mid-trip unpick cannot rewrite the map.
class AisleMemory {
  const AisleMemory(this._rank);

  /// Empty memory: every product is unknown, so arrange() preserves the
  /// incoming order. That is the first-shop case, and also the fail-open
  /// case if history cannot be read.
  static const AisleMemory empty = AisleMemory({});

  /// How strongly the latest shop overwrites what we already knew.
  ///
  /// High enough that a new route (they changed stores, they started at
  /// the opposite end) lands within a couple of trips. Low enough that one
  /// odd shop — they grabbed milk last because they were next to the till —
  /// does not scramble the map.
  static const double recency = 0.35;

  /// product id → typical position in the walk, 0 first, 1 last.
  final Map<int, double> _rank;

  bool get isEmpty => _rank.isEmpty;

  double? rankOf(int? productId) =>
      productId == null ? null : _rank[productId];

  /// Builds memory from completed shops, oldest walk first.
  ///
  /// A walk is the product ids in the order they were ticked. Single-item
  /// shops are skipped: there is no layout information in a list of one.
  /// A product that appears twice in one shop (picked, unpicked, picked)
  /// counts at its first tick — that is when they found it.
  factory AisleMemory.fromWalks(Iterable<List<int>> walksOldestFirst) {
    final rank = <int, double>{};
    for (final walk in walksOldestFirst) {
      final seen = <int>{};
      final unique = <int>[];
      for (final id in walk) {
        if (seen.add(id)) unique.add(id);
      }
      if (unique.length < 2) continue;
      final span = unique.length - 1;
      for (var i = 0; i < unique.length; i++) {
        final fraction = i / span;
        final previous = rank[unique[i]];
        rank[unique[i]] = previous == null
            ? fraction
            : previous * (1 - recency) + fraction * recency;
      }
    }
    return AisleMemory(rank);
  }

  /// Remaining items in store order: things usually found first, first.
  /// Unknown products keep their list order, after anything already mapped.
  List<T> arrange<T>(
    List<T> items, {
    required int? Function(T item) productId,
    required int Function(T item) listOrder,
  }) {
    if (items.length < 2 || _rank.isEmpty) return items;

    final indexed = [for (var i = 0; i < items.length; i++) (i, items[i])];
    indexed.sort((a, b) {
      final ra = rankOf(productId(a.$2));
      final rb = rankOf(productId(b.$2));
      if (ra != null && rb != null) {
        final byRank = ra.compareTo(rb);
        if (byRank != 0) return byRank;
      } else if (ra != null) {
        return -1;
      } else if (rb != null) {
        return 1;
      }
      final byList = listOrder(a.$2).compareTo(listOrder(b.$2));
      if (byList != 0) return byList;
      return a.$1.compareTo(b.$1);
    });
    return [for (final entry in indexed) entry.$2];
  }
}
