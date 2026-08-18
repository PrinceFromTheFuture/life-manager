import 'package:shopping_list/apps/receipts/data/models/expense.dart';
import 'package:shopping_list/apps/receipts/data/models/month_kind_totals.dart';

/// How the month's slips are cut. Named for a filing question, not a date
/// range — the month selector already owns time.
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

/// One statement-week inside a month: days 1–7, 8–14, 15–21, 22–28, 29–end.
class StatementWeek {
  const StatementWeek({
    required this.index,
    required this.fromDay,
    required this.toDay,
    required this.amountMinor,
    required this.businessMinor,
    required this.personalMinor,
  });

  final int index;
  final int fromDay;
  final int toDay;
  final int amountMinor;
  final int businessMinor;
  final int personalMinor;
}

/// Spend on one calendar day, split so a column can print both inks.
class DayKindSpend {
  const DayKindSpend({
    required this.day,
    required this.businessMinor,
    required this.personalMinor,
  });

  final int day;
  final int businessMinor;
  final int personalMinor;

  int get totalMinor => businessMinor + personalMinor;
}

/// Where this month sits against the same day last month.
class MonthPace {
  const MonthPace({
    required this.day,
    required this.daysInMonth,
    required this.spentToDate,
    required this.lastMonthToDate,
    required this.projected,
    required this.monthComplete,
  });

  final int day;
  final int daysInMonth;
  final int spentToDate;
  final int lastMonthToDate;
  final int projected;
  final bool monthComplete;

  int get deltaToDate => spentToDate - lastMonthToDate;
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

  static List<StatementWeek> statementWeeks(
    List<Expense> expenses,
    DateTime month,
  ) {
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final bounds = <(int, int)>[
      (1, 7),
      (8, 14),
      (15, 21),
      (22, 28),
      if (daysInMonth > 28) (29, daysInMonth),
    ];
    final weeks = [
      for (var i = 0; i < bounds.length; i++)
        StatementWeek(
          index: i,
          fromDay: bounds[i].$1,
          toDay: bounds[i].$2.clamp(1, daysInMonth),
          amountMinor: 0,
          businessMinor: 0,
          personalMinor: 0,
        ),
    ];
    for (final e in expenses) {
      final day = e.occurredAt.toLocal().day;
      final slot = (day - 1) ~/ 7;
      if (slot < 0 || slot >= weeks.length) continue;
      final w = weeks[slot];
      weeks[slot] = StatementWeek(
        index: w.index,
        fromDay: w.fromDay,
        toDay: w.toDay,
        amountMinor: w.amountMinor + e.amountMinor,
        businessMinor: w.businessMinor + (e.isBusiness ? e.amountMinor : 0),
        personalMinor: w.personalMinor + (e.isBusiness ? 0 : e.amountMinor),
      );
    }
    return weeks;
  }

  static List<DayKindSpend> dailyKind(
    List<Expense> expenses,
    DateTime month,
  ) {
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final business = List<int>.filled(daysInMonth + 1, 0);
    final personal = List<int>.filled(daysInMonth + 1, 0);
    for (final e in expenses) {
      final day = e.occurredAt.toLocal().day;
      if (day < 1 || day > daysInMonth) continue;
      if (e.isBusiness) {
        business[day] += e.amountMinor;
      } else {
        personal[day] += e.amountMinor;
      }
    }
    return [
      for (var d = 1; d <= daysInMonth; d++)
        DayKindSpend(
          day: d,
          businessMinor: business[d],
          personalMinor: personal[d],
        ),
    ];
  }

  static int weekendSpend(List<Expense> expenses) {
    var sum = 0;
    for (final e in expenses) {
      final weekday = e.occurredAt.toLocal().weekday;
      // The ledger is ILS — the weekend that matters is Friday and Saturday.
      if (weekday == DateTime.friday || weekday == DateTime.saturday) {
        sum += e.amountMinor;
      }
    }
    return sum;
  }

  /// Last twelve calendar months, oldest first, blank months kept so a gap
  /// prints as an empty well rather than a missing column.
  static List<MonthKindTotals> registerMonths(
    List<MonthKindTotals> sparse, {
    DateTime? now,
    int months = 12,
  }) {
    final end = now ?? DateTime.now();
    final thisMonth = DateTime(end.year, end.month);
    final byKey = {
      for (final row in sparse)
        DateTime(row.month.year, row.month.month): row,
    };
    return [
      for (var i = months - 1; i >= 0; i--)
        byKey[DateTime(thisMonth.year, thisMonth.month - i)] ??
            MonthKindTotals(
              month: DateTime(thisMonth.year, thisMonth.month - i),
              businessMinor: 0,
              personalMinor: 0,
            ),
    ];
  }

  static MonthPace pace({
    required DateTime month,
    required List<Expense> thisMonth,
    required int lastMonthToDate,
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final isCurrent = today.year == month.year && today.month == month.month;
    final day = isCurrent ? today.day.clamp(1, daysInMonth) : daysInMonth;
    final spentToDate = isCurrent
        ? totalOf([
            for (final e in thisMonth)
              if (e.occurredAt.toLocal().day <= day) e,
          ])
        : totalOf(thisMonth);
    final projected = day == 0 ? spentToDate : (spentToDate * daysInMonth) ~/ day;
    return MonthPace(
      day: day,
      daysInMonth: daysInMonth,
      spentToDate: spentToDate,
      lastMonthToDate: lastMonthToDate,
      projected: projected,
      monthComplete: !isCurrent,
    );
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
