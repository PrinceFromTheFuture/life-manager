import 'package:shopping_list/apps/receipts/data/models/recurring_rule.dart';
import 'package:shopping_list/apps/receipts/data/receipts_view.dart';

/// How the recurring page cuts its own list. Derived from the templates
/// themselves — never from the slips they later produce.
abstract final class RecurringView {
  /// Sentinel [RecurringGroup.categoryId] for money that arrives.
  static const int incomingId = -1;

  static int expenseTotal(List<RecurringRule> rules) => rules
      .where((r) => !r.isIncome)
      .fold(0, (sum, r) => sum + r.amountMinor);

  static int incomeTotal(List<RecurringRule> rules) => rules
      .where((r) => r.isIncome)
      .fold(0, (sum, r) => sum + r.amountMinor);

  /// Categories ranked by what they cost each month, then income as its own
  /// group if any. Groups are cost-desc; the rows inside a group follow the
  /// day they are usually paid.
  static List<RecurringGroup> grouped(
    List<RecurringRule> rules, {
    required Map<int, String> categoryNames,
  }) {
    final buckets = <int?, List<RecurringRule>>{};
    for (final rule in rules) {
      final key = rule.isIncome ? incomingId : rule.categoryId;
      buckets.putIfAbsent(key, () => []).add(rule);
    }

    final groups = [
      for (final entry in buckets.entries)
        RecurringGroup(
          categoryId: entry.key,
          name: entry.key == incomingId
              ? 'Coming in'
              : (categoryNames[entry.key] ?? 'Unfiled'),
          totalMinor: entry.value.fold(0, (sum, r) => sum + r.amountMinor),
          rules: [
            ...entry.value,
          ]..sort((a, b) {
              final byDay = a.dayOfMonth.compareTo(b.dayOfMonth);
              if (byDay != 0) return byDay;
              return a.name.toLowerCase().compareTo(b.name.toLowerCase());
            }),
        ),
    ]..sort((a, b) {
        if (a.isIncoming != b.isIncoming) return a.isIncoming ? 1 : -1;
        final byTotal = b.totalMinor.compareTo(a.totalMinor);
        if (byTotal != 0) return byTotal;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    return groups;
  }

  /// Category take across expense rules, busiest first — same ranking the
  /// donut in statistics uses.
  static List<CategorySpend> categoryTotals(List<RecurringRule> rules) {
    final amounts = <int?, int>{};
    final counts = <int?, int>{};
    for (final rule in rules) {
      if (rule.isIncome) continue;
      amounts[rule.categoryId] =
          (amounts[rule.categoryId] ?? 0) + rule.amountMinor;
      counts[rule.categoryId] = (counts[rule.categoryId] ?? 0) + 1;
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

  /// One stack per day of the month, 1–31. A day with nothing due is an
  /// empty well, so the month's shape is visible before you read a name.
  static List<List<CategorySlice>> dayStacks(List<RecurringRule> rules) {
    final order = [
      for (final row in categoryTotals(rules)) row.categoryId,
    ];
    final byDay = <int, Map<int?, int>>{
      for (var d = 1; d <= 31; d++) d: {},
    };
    for (final rule in rules) {
      if (rule.isIncome) continue;
      final day = rule.dayOfMonth.clamp(1, 31);
      final bucket = byDay[day]!;
      bucket[rule.categoryId] =
          (bucket[rule.categoryId] ?? 0) + rule.amountMinor;
    }
    return [
      for (var d = 1; d <= 31; d++)
        [
          for (final id in order)
            if ((byDay[d]![id] ?? 0) > 0)
              CategorySlice(categoryId: id, amountMinor: byDay[d]![id]!),
        ],
    ];
  }
}

/// The recurring list, one stamp-pad section.
class RecurringGroup {
  const RecurringGroup({
    required this.categoryId,
    required this.name,
    required this.totalMinor,
    required this.rules,
  });

  /// Null is unfiled. [RecurringView.incomingId] is income.
  final int? categoryId;
  final String name;
  final int totalMinor;
  final List<RecurringRule> rules;

  bool get isIncoming => categoryId == RecurringView.incomingId;
}
