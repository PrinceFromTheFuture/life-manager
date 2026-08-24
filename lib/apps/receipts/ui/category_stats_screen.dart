import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:shopping_list/apps/receipts/data/models/expense.dart';
import 'package:shopping_list/apps/receipts/data/receipts_view.dart';
import 'package:shopping_list/apps/receipts/ui/expense_detail_screen.dart';
import 'package:shopping_list/apps/receipts/ui/stats_charts.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/design/widgets/perforation.dart';
import 'package:shopping_list/core/util/money.dart';

/// One category's plot across the span statistics is standing on, then the
/// slips that made it. Same language as a gym movement's history: a line of
/// ink, then the list.
class CategoryStatsScreen extends StatefulWidget {
  const CategoryStatsScreen({
    super.key,
    required this.categoryId,
    required this.name,
    required this.ink,
    required this.period,
    required this.expenses,
  });

  final int? categoryId;
  final String name;
  final Color ink;
  final StatsPeriod period;
  final List<Expense> expenses;

  @override
  State<CategoryStatsScreen> createState() => _CategoryStatsScreenState();
}

class _CategoryStatsScreenState extends State<CategoryStatsScreen> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    final slips = [
      for (final e in widget.expenses)
        if (e.categoryId == widget.categoryId) e,
    ]..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    final values = ReceiptsView.categorySeries(
      widget.expenses,
      widget.period,
      widget.categoryId,
    );
    final dates = widget.period.days;
    final total = ReceiptsView.totalOf(slips);
    final selected = (_selected ?? _lastSpent(values)).clamp(
      0,
      values.isEmpty ? 0 : values.length - 1,
    );
    final selectedDay = dates.isEmpty ? null : dates[selected];
    final selectedAmount = values.isEmpty ? 0 : values[selected];
    return Scaffold(
      backgroundColor: palette.paper,
      appBar: AppBar(title: Text(widget.name)),
      body: slips.isEmpty
          ? const _EmptyCategory()
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                Space.lg,
                Space.md,
                Space.lg,
                Space.xxl,
              ),
              children: [
                Text(
                  widget.period.grain == StatsGrain.week
                      ? 'THIS WEEK'
                      : DateFormat('MMMM yyyy')
                          .format(widget.period.start)
                          .toUpperCase(),
                  style: Type.eyebrow.copyWith(color: palette.faded),
                ),
                const SizedBox(height: Space.md),
                SpendPlot(
                  values: values,
                  dates: dates,
                  ink: widget.ink,
                  compact: false,
                  height: 168,
                  selectedIndex: selected,
                  onSelect: (i) {
                    HapticFeedback.selectionClick();
                    setState(() => _selected = i);
                  },
                ),
                const SizedBox(height: Space.md),
                Text(
                  Money.format(total),
                  style: Type.item.copyWith(color: palette.print),
                ),
                const SizedBox(height: 2),
                Text(
                  selectedDay == null
                      ? '${slips.length} ${slips.length == 1 ? 'slip' : 'slips'}'
                      : '${DateFormat('EEEE d MMMM').format(selectedDay)} · ${Money.format(selectedAmount)}',
                  style: Type.caption.copyWith(color: palette.faded),
                ),
                const SizedBox(height: Space.lg),
                const PerforatedRule(),
                const SizedBox(height: Space.lg),
                Text(
                  'SLIPS',
                  style: Type.eyebrow.copyWith(color: palette.faded),
                ),
                const SizedBox(height: Space.md),
                for (final slip in slips) ...[
                  _Row(expense: slip, ink: widget.ink),
                  const PerforatedRule(),
                ],
              ],
            ),
    );
  }

  static int _lastSpent(List<int> values) {
    for (var i = values.length - 1; i >= 0; i--) {
      if (values[i] > 0) return i;
    }
    return values.isEmpty ? 0 : values.length - 1;
  }
}

class _EmptyCategory extends StatelessWidget {
  const _EmptyCategory();

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PerforatedRule(),
          const SizedBox(height: Space.lg),
          Text(
            'Nothing in this pad.',
            style: Type.display.copyWith(color: palette.print, fontSize: 26),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.expense, required this.ink});

  final Expense expense;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    return InkWell(
      onTap: expense.id == null
          ? null
          : () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      ExpenseDetailScreen(expenseId: expense.id!),
                ),
              ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.md),
        child: Row(
          children: [
            Container(width: 3, height: 26, color: ink),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    expense.title,
                    style: Type.item.copyWith(color: palette.print),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('d MMM · HH:mm')
                        .format(expense.occurredAt.toLocal()),
                    style: Type.caption.copyWith(color: palette.faded),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Space.md),
            Text(
              expense.amountLabel,
              style: Type.monoBold.copyWith(color: palette.print),
            ),
          ],
        ),
      ),
    );
  }
}
