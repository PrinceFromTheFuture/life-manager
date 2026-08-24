import 'package:shopping_list/apps/receipts/data/finance/calendar.dart';
import 'package:shopping_list/apps/receipts/data/models/expense.dart';

/// How the month's slips are cut. Named for a filing question, not a date
/// range — the month selector already owns time on the roll of slips.
enum ReceiptsLens {
  all,

  /// Marked to claim.
  toClaim,

  personal,

  /// No category yet — still sitting in the inbox.
  unfiled,

  /// The slips that dominate the month: at or above the upper quartile.
  large,
}

/// How the month's slips are ordered.
enum ReceiptsSort {
  newest,
  oldest,
  largest,
  merchant,
}

/// One shop's take on the month.
class MerchantTotal {
  const MerchantTotal({
    required this.name,
    required this.count,
    required this.amountMinor,
  });

  final String name;
  final int count;
  final int amountMinor;
}

/// Week or month, the two grains statistics can stand on.
enum StatsGrain { week, month }

/// A closed span of days statistics is looking at.
///
/// [start] is local midnight on the first day — Monday for a week, the 1st
/// for a month — so it can double as a query bound.
class StatsPeriod {
  const StatsPeriod({required this.grain, required this.start});

  final StatsGrain grain;
  final DateTime start;

  factory StatsPeriod.containing(DateTime date, StatsGrain grain) {
    final day = Calendar.startOfDay(date);
    return StatsPeriod(
      grain: grain,
      start: grain == StatsGrain.week
          ? Calendar.startOfWeek(day)
          : Calendar.startOfMonth(day),
    );
  }

  factory StatsPeriod.current({
    DateTime? now,
    StatsGrain grain = StatsGrain.week,
  }) =>
      StatsPeriod.containing(now ?? DateTime.now(), grain);

  /// Exclusive end, so a `between` query does not leak into the next span.
  DateTime get endExclusive => grain == StatsGrain.week
      ? start.add(const Duration(days: 7))
      : DateTime(start.year, start.month + 1);

  DateTime get lastDay => endExclusive.subtract(const Duration(days: 1));

  int get dayCount => endExclusive.difference(start).inDays;

  List<DateTime> get days => [
        for (var i = 0; i < dayCount; i++) start.add(Duration(days: i)),
      ];

  bool contains(DateTime date) {
    final day = Calendar.startOfDay(date.toLocal());
    return !day.isBefore(start) && day.isBefore(endExclusive);
  }

  StatsPeriod get previous => StatsPeriod(
        grain: grain,
        start: grain == StatsGrain.week
            ? start.subtract(const Duration(days: 7))
            : DateTime(start.year, start.month - 1),
      );

  StatsPeriod get next => StatsPeriod(
        grain: grain,
        start: grain == StatsGrain.week
            ? start.add(const Duration(days: 7))
            : DateTime(start.year, start.month + 1),
      );

  bool isCurrent({DateTime? now}) {
    final current = StatsPeriod.containing(now ?? DateTime.now(), grain);
    return current.start == start;
  }

  bool canAdvance({DateTime? now}) {
    final current = StatsPeriod.containing(now ?? DateTime.now(), grain);
    return start.isBefore(current.start);
  }

  StatsPeriod withGrain(StatsGrain grain) {
    if (grain == this.grain) return this;
    return StatsPeriod.containing(start, grain);
  }

  StatsPeriod at(DateTime date) => StatsPeriod.containing(date, grain);

  /// How many grains [other] is from this one. Same grain only.
  int offsetTo(StatsPeriod other) {
    if (other.grain != grain) return 0;
    if (grain == StatsGrain.week) {
      return other.start.difference(start).inDays ~/ 7;
    }
    return (other.start.year - start.year) * 12 +
        (other.start.month - start.month);
  }

  StatsPeriod shift(int steps) {
    if (steps == 0) return this;
    if (grain == StatsGrain.week) {
      return StatsPeriod(
        grain: grain,
        start: start.add(Duration(days: 7 * steps)),
      );
    }
    return StatsPeriod(
      grain: grain,
      start: DateTime(start.year, start.month + steps),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is StatsPeriod && other.grain == grain && other.start == start;

  @override
  int get hashCode => Object.hash(grain, start);
}

/// One category's take on a day, so a well can print its inks in order.
class CategorySlice {
  const CategorySlice({
    required this.categoryId,
    required this.amountMinor,
  });

  final int? categoryId;
  final int amountMinor;
}

/// Spend on one calendar day, stacked by category rather than by kind.
class DayCategorySpend {
  const DayCategorySpend({
    required this.day,
    required this.slices,
    required this.totalMinor,
  });

  final DateTime day;
  final List<CategorySlice> slices;
  final int totalMinor;
}

/// One category's take on a period.
class CategorySpend {
  const CategorySpend({
    required this.categoryId,
    required this.amountMinor,
    required this.count,
  });

  final int? categoryId;
  final int amountMinor;
  final int count;
}

abstract final class ReceiptsView {
  static List<Expense> apply(
    List<Expense> expenses, {
    required ReceiptsLens lens,
    required ReceiptsSort sort,
  }) {
    final cutoff = largeCutoff(expenses);
    final filtered = [
      for (final e in expenses)
        if (matches(e, lens, cutoff)) e,
    ];
    filtered.sort((a, b) => compare(a, b, sort));
    return filtered;
  }

  static bool matches(Expense e, ReceiptsLens lens, int? largeAt) {
    switch (lens) {
      case ReceiptsLens.all:
        return true;
      case ReceiptsLens.toClaim:
        return e.isBusiness;
      case ReceiptsLens.personal:
        return !e.isBusiness;
      case ReceiptsLens.unfiled:
        return e.categoryId == null;
      case ReceiptsLens.large:
        return largeAt != null && e.amountMinor >= largeAt;
    }
  }

  static int compare(Expense a, Expense b, ReceiptsSort sort) {
    switch (sort) {
      case ReceiptsSort.newest:
        final byDate = b.occurredAt.compareTo(a.occurredAt);
        if (byDate != 0) return byDate;
        return (b.id ?? 0).compareTo(a.id ?? 0);
      case ReceiptsSort.oldest:
        final byDate = a.occurredAt.compareTo(b.occurredAt);
        if (byDate != 0) return byDate;
        return (a.id ?? 0).compareTo(b.id ?? 0);
      case ReceiptsSort.largest:
        final byAmount = b.amountMinor.compareTo(a.amountMinor);
        if (byAmount != 0) return byAmount;
        return b.occurredAt.compareTo(a.occurredAt);
      case ReceiptsSort.merchant:
        final byName = a.title.toLowerCase().compareTo(b.title.toLowerCase());
        if (byName != 0) return byName;
        return b.occurredAt.compareTo(a.occurredAt);
    }
  }

  /// Upper quartile of amounts. Needs four slips or it isn't a quartile.
  static int? largeCutoff(List<Expense> expenses) {
    if (expenses.length < 4) return null;
    final amounts = [for (final e in expenses) e.amountMinor]..sort();
    final i = (amounts.length * 3) ~/ 4;
    return amounts[i.clamp(0, amounts.length - 1)];
  }

  static int totalOf(List<Expense> expenses) =>
      expenses.fold(0, (sum, e) => sum + e.amountMinor);

  static DateTime dayOf(Expense expense) {
    final local = expense.occurredAt.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  static List<MerchantTotal> merchantTape(List<Expense> expenses) {
    final map = <String, MerchantTotal>{};
    for (final e in expenses) {
      final name = e.title;
      final current = map[name];
      map[name] = MerchantTotal(
        name: name,
        count: (current?.count ?? 0) + 1,
        amountMinor: (current?.amountMinor ?? 0) + e.amountMinor,
      );
    }
    final rows = map.values.toList()
      ..sort((a, b) {
        final byAmount = b.amountMinor.compareTo(a.amountMinor);
        if (byAmount != 0) return byAmount;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    return rows;
  }

  /// Categories ranked by take, busiest first — the order every chart in
  /// statistics uses, so a pad of ink sits in the same place on the well,
  /// the ring, and the list.
  static List<CategorySpend> categoryTotals(List<Expense> expenses) {
    final amounts = <int?, int>{};
    final counts = <int?, int>{};
    for (final e in expenses) {
      amounts[e.categoryId] = (amounts[e.categoryId] ?? 0) + e.amountMinor;
      counts[e.categoryId] = (counts[e.categoryId] ?? 0) + 1;
    }
    final rows = [
      for (final id in amounts.keys)
        CategorySpend(
          categoryId: id,
          amountMinor: amounts[id]!,
          count: counts[id]!,
        ),
    ]..sort((a, b) {
        final byAmount = b.amountMinor.compareTo(a.amountMinor);
        if (byAmount != 0) return byAmount;
        return (a.categoryId ?? 1 << 30).compareTo(b.categoryId ?? 1 << 30);
      });
    return rows;
  }

  /// One well per day in [period]. Slices share the period's category order
  /// so Monday's groceries sit at the same height as Thursday's.
  static List<DayCategorySpend> dailyStacks(
    List<Expense> expenses,
    StatsPeriod period,
  ) {
    final order = [
      for (final row in categoryTotals(expenses)) row.categoryId,
    ];
    final byDay = <DateTime, Map<int?, int>>{
      for (final day in period.days) day: {},
    };
    for (final e in expenses) {
      final day = dayOf(e);
      final bucket = byDay[day];
      if (bucket == null) continue;
      bucket[e.categoryId] = (bucket[e.categoryId] ?? 0) + e.amountMinor;
    }
    return [
      for (final day in period.days)
        DayCategorySpend(
          day: day,
          totalMinor: byDay[day]!.values.fold(0, (sum, n) => sum + n),
          slices: [
            for (final id in order)
              if ((byDay[day]![id] ?? 0) > 0)
                CategorySlice(
                  categoryId: id,
                  amountMinor: byDay[day]![id]!,
                ),
          ],
        ),
    ];
  }

  /// Daily take for one category across [period], zeros kept so a quiet day
  /// is a rest in the line rather than a missing point.
  static List<int> categorySeries(
    List<Expense> expenses,
    StatsPeriod period,
    int? categoryId,
  ) {
    final byDay = {for (final day in period.days) day: 0};
    for (final e in expenses) {
      if (e.categoryId != categoryId) continue;
      final day = dayOf(e);
      if (!byDay.containsKey(day)) continue;
      byDay[day] = byDay[day]! + e.amountMinor;
    }
    return [for (final day in period.days) byDay[day]!];
  }

  static List<Expense> onDay(List<Expense> expenses, DateTime day) {
    final key = Calendar.startOfDay(day);
    final slips = [
      for (final e in expenses)
        if (Calendar.isSameDay(dayOf(e), key)) e,
    ];
    slips.sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
    return slips;
  }
}

extension ReceiptsLensCopy on ReceiptsLens {
  String get label {
    switch (this) {
      case ReceiptsLens.all:
        return 'All';
      case ReceiptsLens.toClaim:
        return 'To claim';
      case ReceiptsLens.personal:
        return 'Personal';
      case ReceiptsLens.unfiled:
        return 'Unfiled';
      case ReceiptsLens.large:
        return 'Large slips';
    }
  }

  String get empty {
    switch (this) {
      case ReceiptsLens.all:
        return 'No expenses this month.';
      case ReceiptsLens.toClaim:
        return 'Nothing to claim this month.';
      case ReceiptsLens.personal:
        return 'No personal slips this month.';
      case ReceiptsLens.unfiled:
        return 'Everything is filed.';
      case ReceiptsLens.large:
        return 'No large slips this month.';
    }
  }
}

extension ReceiptsSortCopy on ReceiptsSort {
  String get label {
    switch (this) {
      case ReceiptsSort.newest:
        return 'Newest';
      case ReceiptsSort.oldest:
        return 'Oldest';
      case ReceiptsSort.largest:
        return 'Largest';
      case ReceiptsSort.merchant:
        return 'Merchant';
    }
  }
}
