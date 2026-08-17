import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:shopping_list/apps/receipts/data/models/expense.dart';
import 'package:shopping_list/apps/receipts/data/models/expense_category.dart';
import 'package:shopping_list/apps/receipts/data/models/month_kind_totals.dart';
import 'package:shopping_list/apps/receipts/state/providers.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/design/widgets/perforation.dart';
import 'package:shopping_list/core/util/money.dart';

/// Where the money went this month.
///
/// Two views, both built without a chart package: a sorted breakdown by
/// category, and a day-by-day column for the month. Both use exactly one
/// colour — the app's ink — because every bar is already labelled with the
/// category name or the date; colour would carry no identity a categorical
/// palette could add, and a second hue with no job to do is decoration, not
/// information.
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.thermal;
    final month = ref.watch(selectedMonthProvider);
    final expensesAsync = ref.watch(monthExpensesProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      backgroundColor: palette.paper,
      appBar: AppBar(title: const Text('Statistics')),
      body: expensesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('$e', style: Type.caption.copyWith(color: palette.faded)),
        ),
        data: (expenses) => categoriesAsync.maybeWhen(
          data: (categories) => _StatsBody(
            month: month,
            expenses: expenses,
            categories: categories,
          ),
          orElse: () => const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }
}

class _StatsBody extends ConsumerWidget {
  const _StatsBody({
    required this.month,
    required this.expenses,
    required this.categories,
  });

  final DateTime month;
  final List<Expense> expenses;
  final List<ExpenseCategory> categories;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.thermal;
    final previousTotal = ref.watch(previousMonthTotalProvider);

    if (expenses.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PerforatedRule(),
              const SizedBox(height: Space.lg),
              Text(
                'Nothing to show yet.',
                style:
                    Type.display.copyWith(color: palette.print, fontSize: 26),
              ),
              const SizedBox(height: Space.md),
              Text(
                'Statistics fill in once you have logged an expense this '
                'month.',
                style: Type.body.copyWith(color: palette.faded),
              ),
            ],
          ),
        ),
      );
    }

    final total = expenses.fold<int>(0, (sum, e) => sum + e.amountMinor);
    final categoryNames = {for (final c in categories) c.id: c.name};

    return ListView(
      padding:
          const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, Space.xxl),
      children: [
        Text(
          DateFormat('MMMM yyyy').format(month).toUpperCase(),
          style: Type.eyebrow.copyWith(color: palette.faded),
        ),
        const SizedBox(height: Space.sm),
        Text(
          Money.format(total),
          style: Type.totalDisplay.copyWith(color: palette.print),
        ),
        previousTotal.maybeWhen(
          data: (previous) {
            final delta = _DeltaStat.compute(total, previous);
            if (delta == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: Space.xs),
              child: Text(
                delta.label,
                style: Type.caption.copyWith(color: palette.faded),
              ),
            );
          },
          orElse: () => const SizedBox.shrink(),
        ),
        const SizedBox(height: Space.lg),
        const PerforatedRule(),
        const SizedBox(height: Space.xl),
        Text('BY KIND', style: Type.eyebrow.copyWith(color: palette.faded)),
        const SizedBox(height: Space.lg),
        _KindBreakdown(expenses: expenses, total: total),
        const SizedBox(height: Space.xl),
        const PerforatedRule(),
        const SizedBox(height: Space.xl),
        Text('BY CATEGORY', style: Type.eyebrow.copyWith(color: palette.faded)),
        const SizedBox(height: Space.lg),
        _CategoryBreakdown(
          expenses: expenses,
          categoryNames: categoryNames,
          total: total,
        ),
        const SizedBox(height: Space.xl),
        const PerforatedRule(),
        const SizedBox(height: Space.xl),
        Text('BY MONTH', style: Type.eyebrow.copyWith(color: palette.faded)),
        const SizedBox(height: Space.lg),
        const _MonthKindHistory(),
        const SizedBox(height: Space.xl),
        const PerforatedRule(),
        const SizedBox(height: Space.xl),
        Text('BY DAY', style: Type.eyebrow.copyWith(color: palette.faded)),
        const SizedBox(height: Space.lg),
        _DailySpend(month: month, expenses: expenses),
      ],
    );
  }
}

/// The percentage move against last month, in the interface's plain voice —
/// never shown when there is nothing to compare against.
class _DeltaStat {
  const _DeltaStat({required this.label});

  final String label;

  static _DeltaStat? compute(int current, int previous) {
    if (previous == 0) return null;
    final change = ((current - previous) / previous * 100).round();
    if (change == 0) return const _DeltaStat(label: 'Same as last month');
    final direction = change > 0 ? 'up' : 'down';
    return _DeltaStat(label: '${change.abs()}% $direction on last month');
  }
}

/// Business vs personal for the month on screen. Two bars, same ink — the
/// labels carry the distinction, not a second colour.
class _KindBreakdown extends StatelessWidget {
  const _KindBreakdown({required this.expenses, required this.total});

  final List<Expense> expenses;
  final int total;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    var business = 0;
    var personal = 0;
    for (final e in expenses) {
      if (e.isBusiness) {
        business += e.amountMinor;
      } else {
        personal += e.amountMinor;
      }
    }
    final max = business > personal ? business : personal;
    if (max == 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CategoryRow(
          label: 'Business',
          amountMinor: business,
          fraction: business / max,
          ink: palette.carbon,
        ),
        const SizedBox(height: Space.md),
        _CategoryRow(
          label: 'Personal',
          amountMinor: personal,
          fraction: personal / max,
          ink: palette.carbon.withValues(alpha: 0.55),
        ),
        if (total > 0 && business > 0) ...[
          const SizedBox(height: Space.sm),
          Text(
            '${((business / total) * 100).round()}% of this month is business',
            style: Type.caption.copyWith(color: palette.faded),
          ),
        ],
      ],
    );
  }
}

/// Last twelve months of business vs personal, so a claimed cost is visible
/// without paging the list back one month at a time.
class _MonthKindHistory extends ConsumerWidget {
  const _MonthKindHistory();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.thermal;
    final history = ref.watch(kindTotalsByMonthProvider);

    return history.maybeWhen(
      data: (months) {
        if (months.isEmpty) {
          return Text(
            'No months to compare yet.',
            style: Type.caption.copyWith(color: palette.faded),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < months.length; i++) ...[
              _MonthKindRow(totals: months[i]),
              if (i != months.length - 1) const SizedBox(height: Space.lg),
            ],
          ],
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _MonthKindRow extends StatelessWidget {
  const _MonthKindRow({required this.totals});

  final MonthKindTotals totals;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          DateFormat('MMMM yyyy').format(totals.month).toUpperCase(),
          style: Type.caption.copyWith(color: palette.faded),
        ),
        const SizedBox(height: Space.xs),
        Row(
          children: [
            Expanded(
              child: Text(
                'Business',
                style: Type.item.copyWith(color: palette.print),
              ),
            ),
            Text(
              Money.format(totals.businessMinor),
              style: Type.monoBold.copyWith(color: palette.print),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Expanded(
              child: Text(
                'Personal',
                style: Type.caption.copyWith(color: palette.faded),
              ),
            ),
            Text(
              Money.format(totals.personalMinor),
              style: Type.mono.copyWith(color: palette.faded),
            ),
          ],
        ),
      ],
    );
  }
}

/// Sorted horizontal bars, one per category, each carrying its own label and
/// amount — the label *is* the identity encoding, so every bar shares the
/// app's single ink rather than a categorical palette that would have
/// nothing left to distinguish.
class _CategoryBreakdown extends StatelessWidget {
  const _CategoryBreakdown({
    required this.expenses,
    required this.categoryNames,
    required this.total,
  });

  final List<Expense> expenses;
  final Map<int?, String> categoryNames;
  final int total;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    final totals = <int?, int>{};
    for (final e in expenses) {
      totals[e.categoryId] = (totals[e.categoryId] ?? 0) + e.amountMinor;
    }
    final sorted = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final max = sorted.first.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in sorted) ...[
          _CategoryRow(
            label: categoryNames[entry.key] ?? 'Uncategorised',
            amountMinor: entry.value,
            fraction: entry.value / max,
            ink: palette.carbon,
          ),
          const SizedBox(height: Space.md),
        ],
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.label,
    required this.amountMinor,
    required this.fraction,
    required this.ink,
  });

  final String label;
  final int amountMinor;
  final double fraction;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Type.item.copyWith(color: palette.print),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              Money.format(amountMinor),
              style: Type.monoBold.copyWith(color: palette.print),
            ),
          ],
        ),
        const SizedBox(height: Space.xs),
        LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                Container(
                  height: 8,
                  width: constraints.maxWidth,
                  decoration: BoxDecoration(
                    color: palette.paperShade,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                AnimatedContainer(
                  duration: Motion.settle,
                  curve: Motion.heat,
                  height: 8,
                  width: constraints.maxWidth * fraction.clamp(0.0, 1.0),
                  decoration: BoxDecoration(
                    color: ink,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Thin columns, one per day of the month, height proportional to that day's
/// spend. Tapping a column is the hover-equivalent on a touch screen: it
/// reveals the exact figure below the chart rather than in a floating
/// tooltip, which would be clipped at the screen edge on the first and last
/// few days.
class _DailySpend extends StatefulWidget {
  const _DailySpend({required this.month, required this.expenses});

  final DateTime month;
  final List<Expense> expenses;

  @override
  State<_DailySpend> createState() => _DailySpendState();
}

class _DailySpendState extends State<_DailySpend> {
  int? _selectedDay;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    final daysInMonth =
        DateTime(widget.month.year, widget.month.month + 1, 0).day;
    final byDay = List<int>.filled(daysInMonth + 1, 0);
    for (final e in widget.expenses) {
      final local = e.occurredAt.toLocal();
      byDay[local.day] += e.amountMinor;
    }
    final max = byDay.reduce((a, b) => a > b ? a : b);

    final selected = _selectedDay;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 120,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var day = 1; day <= daysInMonth; day++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: GestureDetector(
                      onTap: () => setState(
                        () => _selectedDay = _selectedDay == day ? null : day,
                      ),
                      child: Semantics(
                        label: 'Day $day, ${Money.format(byDay[day])}',
                        child: _DayBar(
                          fraction: max == 0 ? 0 : byDay[day] / max,
                          selected: selected == day,
                          hasSpend: byDay[day] > 0,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: Space.xs),
        Container(height: 1, color: palette.perforation),
        const SizedBox(height: Space.sm),
        Text(
          selected == null
              ? 'Tap a day for its total.'
              : '${DateFormat('d MMMM').format(DateTime(widget.month.year, widget.month.month, selected))} · '
                  '${Money.format(byDay[selected])}',
          style: Type.caption.copyWith(color: palette.faded),
        ),
      ],
    );
  }
}

class _DayBar extends StatelessWidget {
  const _DayBar({
    required this.fraction,
    required this.selected,
    required this.hasSpend,
  });

  final double fraction;
  final bool selected;
  final bool hasSpend;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    // A day with nothing spent still gets a hairline mark at the baseline —
    // it read as a rendering glitch when it simply vanished.
    final height =
        hasSpend ? (fraction.clamp(0.0, 1.0) * 116).clamp(4.0, 116.0) : 2.0;

    return Align(
      alignment: Alignment.bottomCenter,
      child: AnimatedContainer(
        duration: Motion.quick,
        height: height,
        decoration: BoxDecoration(
          color: selected
              ? palette.carbon
              : palette.carbon.withValues(alpha: 0.55),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
        ),
      ),
    );
  }
}
