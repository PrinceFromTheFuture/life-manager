import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:shopping_list/apps/receipts/data/finance/calendar.dart';
import 'package:shopping_list/apps/receipts/data/models/expense.dart';
import 'package:shopping_list/apps/receipts/data/receipts_view.dart';
import 'package:shopping_list/apps/receipts/state/providers.dart';
import 'package:shopping_list/apps/receipts/ui/category_stats_screen.dart';
import 'package:shopping_list/apps/receipts/ui/expense_detail_screen.dart';
import 'package:shopping_list/apps/receipts/ui/ledger_plate.dart';
import 'package:shopping_list/apps/receipts/ui/stats_charts.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/design/widgets/app_icon.dart';
import 'package:shopping_list/core/design/widgets/count_up_money.dart';
import 'package:shopping_list/core/design/widgets/perforation.dart';
import 'package:shopping_list/core/util/money.dart';

/// Where the money went this week — or this month.
///
/// Built like gym progress: a week of wells, then a breakdown by the thing
/// that actually organises the work. Here that thing is the category stamp,
/// not business vs personal. The span lives in [statsPeriodProvider], so
/// paging a week does not drag the slips list off its month.
class StatsSection extends ConsumerStatefulWidget {
  const StatsSection({super.key});

  @override
  ConsumerState<StatsSection> createState() => _StatsSectionState();
}

class _StatsSectionState extends ConsumerState<StatsSection> {
  DateTime? _selectedDay;
  int? _donutId;
  var _donutPinned = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    final period = ref.watch(statsPeriodProvider);
    final expensesAsync = ref.watch(statsExpensesProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    ref.listen(statsPeriodProvider, (prev, next) {
      if (prev == next) return;
      setState(() {
        _selectedDay = next.contains(DateTime.now())
            ? Calendar.startOfDay(DateTime.now())
            : null;
        _donutPinned = false;
      });
    });

    final expenses = expensesAsync.valueOrNull;
    final categories = categoriesAsync.valueOrNull;
    if (expenses == null || categories == null) {
      if (expensesAsync.hasError) {
        return Center(
          child: Text(
            '${expensesAsync.error}',
            style: Type.caption.copyWith(color: palette.faded),
          ),
        );
      }
      if (categoriesAsync.hasError) {
        return Center(
          child: Text(
            '${categoriesAsync.error}',
            style: Type.caption.copyWith(color: palette.faded),
          ),
        );
      }
      return const Center(child: CircularProgressIndicator());
    }

    final brightness = Theme.of(context).brightness;
    final inks = <int?, Color>{
      null: palette.faded,
      for (final c in categories) c.id: c.stamp.of(brightness),
    };
    final names = <int?, String>{
      null: 'Unfiled',
      for (final c in categories) c.id: c.name,
    };
    final stacks = ReceiptsView.dailyStacks(expenses, period);
    final totals = ReceiptsView.categoryTotals(expenses);
    final selectedDay = _selectedDay != null && period.contains(_selectedDay!)
        ? _selectedDay
        : null;
    final daySlips = selectedDay == null
        ? const <Expense>[]
        : ReceiptsView.onDay(expenses, selectedDay);
    final donutId = _donutPinned
        ? _donutId
        : (totals.isEmpty ? null : totals.first.categoryId);

    return GestureDetector(
      onHorizontalDragEnd: (details) => _swipe(details, period),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          Space.lg,
          Space.lg,
          Space.lg,
          Space.xxl,
        ),
        children: [
          Text(
            period.grain == StatsGrain.week ? 'BY DAY' : 'BY DAY',
            style: Type.eyebrow.copyWith(color: palette.faded),
          ),
          const SizedBox(height: Space.sm),
          Text(
            selectedDay == null
                ? (period.grain == StatsGrain.week
                    ? 'Tap a day — swipe for another week.'
                    : 'Tap a day — swipe for another month.')
                : DateFormat('EEEE d MMMM').format(selectedDay),
            style: Type.caption.copyWith(color: palette.faded),
          ),
          const SizedBox(height: Space.md),
          DaySpendChart(
            days: stacks,
            inks: inks,
            grain: period.grain,
            selected: selectedDay,
            onSelect: (day, {required toggle}) {
              setState(() {
                if (toggle &&
                    selectedDay != null &&
                    Calendar.isSameDay(selectedDay, day)) {
                  _selectedDay = null;
                } else {
                  _selectedDay = day;
                }
              });
            },
          ),
          AnimatedSize(
            duration: Motion.settle,
            curve: Motion.heat,
            alignment: Alignment.topCenter,
            child: selectedDay == null
                ? const SizedBox(width: double.infinity)
                : _DaySlips(
                    slips: daySlips,
                    inks: inks,
                  ),
          ),
          const SizedBox(height: Space.lg),
          const PerforatedRule(),
          const SizedBox(height: Space.xl),
          Text(
            'BY CATEGORY',
            style: Type.eyebrow.copyWith(color: palette.faded),
          ),
          const SizedBox(height: Space.sm),
          Text(
            totals.isEmpty
                ? (period.grain == StatsGrain.week
                    ? 'Nothing stamped this week.'
                    : 'Nothing stamped this month.')
                : 'The ring is the pads. Tap a pad, tap the hole to open it.',
            style: Type.caption.copyWith(color: palette.faded),
          ),
          if (totals.isNotEmpty) ...[
            const SizedBox(height: Space.md),
            CategoryDonut(
              slices: [
                for (final row in totals)
                  DonutSlice(
                    categoryId: row.categoryId,
                    name: names[row.categoryId] ?? 'Unfiled',
                    amountMinor: row.amountMinor,
                    ink: inks[row.categoryId] ?? palette.faded,
                  ),
              ],
              totalMinor: ReceiptsView.totalOf(expenses),
              selectedId: donutId,
              onSelect: (id) => setState(() {
                _donutId = id;
                _donutPinned = true;
              }),
              onOpen: totals.isEmpty
                  ? null
                  : () => _openCategory(
                        context,
                        categoryId: donutId,
                        name: names[donutId] ?? 'Unfiled',
                        ink: inks[donutId] ?? palette.faded,
                        period: period,
                        expenses: expenses,
                      ),
            ),
            const SizedBox(height: Space.xl),
            const PerforatedRule(),
            const SizedBox(height: Space.lg),
            for (var i = 0; i < totals.length; i++) ...[
              _CategoryRow(
                name: names[totals[i].categoryId] ?? 'Unfiled',
                spend: totals[i],
                ink: inks[totals[i].categoryId] ?? palette.faded,
                values: ReceiptsView.categorySeries(
                  expenses,
                  period,
                  totals[i].categoryId,
                ),
                onTap: () => _openCategory(
                  context,
                  categoryId: totals[i].categoryId,
                  name: names[totals[i].categoryId] ?? 'Unfiled',
                  ink: inks[totals[i].categoryId] ?? palette.faded,
                  period: period,
                  expenses: expenses,
                ),
              ),
              if (i != totals.length - 1) ...[
                const SizedBox(height: Space.md),
                const PerforatedRule(),
                const SizedBox(height: Space.md),
              ],
            ],
          ] else ...[
            const SizedBox(height: Space.lg),
            Text(
              period.grain == StatsGrain.week
                  ? 'Nothing this week.'
                  : 'Nothing this month.',
              style: Type.display.copyWith(color: palette.print, fontSize: 26),
            ),
            const SizedBox(height: Space.md),
            Text(
              period.grain == StatsGrain.week
                  ? 'Swipe for another week, or log a slip.'
                  : 'Swipe for another month, or log a slip.',
              style: Type.body.copyWith(color: palette.faded),
            ),
          ],
        ],
      ),
    );
  }

  void _swipe(DragEndDetails details, StatsPeriod period) {
    final v = details.primaryVelocity ?? 0;
    if (v > 280) {
      ref.read(statsPeriodProvider.notifier).state = period.previous;
    } else if (v < -280) {
      if (period.canAdvance()) {
        ref.read(statsPeriodProvider.notifier).state = period.next;
      }
    }
  }

  void _openCategory(
    BuildContext context, {
    required int? categoryId,
    required String name,
    required Color ink,
    required StatsPeriod period,
    required List<Expense> expenses,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CategoryStatsScreen(
          categoryId: categoryId,
          name: name,
          ink: ink,
          period: period,
          expenses: expenses,
        ),
      ),
    );
  }
}

/// Headline for the statistics tab: grain, span, and the total that belongs
/// in the same slot as the slips month selector.
class StatsSummary extends ConsumerWidget {
  const StatsSummary({super.key});

  Future<void> _pickDate(
    BuildContext context,
    WidgetRef ref,
    StatsPeriod period,
  ) async {
    final now = DateTime.now();
    final initial = period.contains(now) ? now : period.start;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year, now.month, now.day),
      initialDatePickerMode: period.grain == StatsGrain.month
          ? DatePickerMode.year
          : DatePickerMode.day,
      helpText: period.grain == StatsGrain.month ? 'Which month?' : 'Which week?',
      useRootNavigator: false,
    );
    if (picked == null) return;
    ref.read(statsPeriodProvider.notifier).state = period.at(picked);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.thermal;
    final period = ref.watch(statsPeriodProvider);
    final total = ref.watch(statsTotalProvider);
    final canAdvance = period.canAdvance();

    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.lg, Space.md),
      child: Column(
        children: [
          Row(
            children: [
              LedgerPlate(
                label: 'Week',
                selected: period.grain == StatsGrain.week,
                onTap: () => ref.read(statsPeriodProvider.notifier).state =
                    period.withGrain(StatsGrain.week),
              ),
              const SizedBox(width: Space.sm),
              LedgerPlate(
                label: 'Month',
                selected: period.grain == StatsGrain.month,
                onTap: () => ref.read(statsPeriodProvider.notifier).state =
                    period.withGrain(StatsGrain.month),
              ),
            ],
          ),
          const SizedBox(height: Space.sm),
          Row(
            children: [
              IconButton(
                icon: const AppIcon(SolarIcons.AltArrowLeft),
                tooltip: period.grain == StatsGrain.week
                    ? 'Previous week'
                    : 'Previous month',
                onPressed: () => ref.read(statsPeriodProvider.notifier).state =
                    period.previous,
              ),
              Expanded(
                child: InkWell(
                  onTap: () => _pickDate(context, ref, period),
                  child: Column(
                    children: [
                      Text(
                        _eyebrow(period),
                        style: Type.eyebrow.copyWith(color: palette.faded),
                      ),
                      const SizedBox(height: Space.xs),
                      total.maybeWhen(
                        data: (amount) => CountUpMoney(
                          amountMinor: amount,
                          style: Type.totalDisplay.copyWith(
                            color: palette.print,
                            fontSize: 32,
                          ),
                        ),
                        orElse: () => Text(
                          '—',
                          style: Type.totalDisplay.copyWith(
                            color: palette.print,
                            fontSize: 32,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: const AppIcon(SolarIcons.AltArrowRight),
                tooltip: period.grain == StatsGrain.week
                    ? 'Next week'
                    : 'Next month',
                onPressed: canAdvance
                    ? () => ref.read(statsPeriodProvider.notifier).state =
                        period.next
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _eyebrow(StatsPeriod period) {
    if (period.grain == StatsGrain.week) {
      if (period.isCurrent()) return 'THIS WEEK';
      return 'WEEK OF ${DateFormat('d MMM').format(period.start).toUpperCase()}';
    }
    return DateFormat('MMMM yyyy').format(period.start).toUpperCase();
  }
}

class _DaySlips extends StatelessWidget {
  const _DaySlips({required this.slips, required this.inks});

  final List<Expense> slips;
  final Map<int?, Color> inks;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: Space.md),
        const PerforatedRule(),
        if (slips.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.md),
            child: Text(
              'Nothing spent.',
              style: Type.caption.copyWith(color: palette.faded),
            ),
          )
        else
          for (final slip in slips)
            _SlipTile(
              expense: slip,
              ink: inks[slip.categoryId],
              caption: DateFormat('HH:mm').format(slip.occurredAt.toLocal()),
            ),
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.name,
    required this.spend,
    required this.ink,
    required this.values,
    required this.onTap,
  });

  final String name;
  final CategorySpend spend;
  final Color ink;
  final List<int> values;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    final slips = spend.count == 1 ? '1 slip' : '${spend.count} slips';

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 3, height: 16, color: ink),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: Text(
                    name,
                    style: Type.item.copyWith(color: palette.print),
                  ),
                ),
                Text(
                  slips,
                  style: Type.mono.copyWith(color: palette.faded, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.only(left: 11),
              child: Text(
                Money.format(spend.amountMinor),
                style: Type.caption.copyWith(color: palette.faded),
              ),
            ),
            if (values.any((v) => v > 0)) ...[
              const SizedBox(height: Space.sm),
              SpendPlot(values: values, ink: ink, height: 64),
            ],
          ],
        ),
      ),
    );
  }
}

class _SlipTile extends StatelessWidget {
  const _SlipTile({
    required this.expense,
    required this.caption,
    this.ink,
  });

  final Expense expense;
  final String caption;
  final Color? ink;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    return InkWell(
      onTap: expense.id == null
          ? null
          : () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ExpenseDetailScreen(expenseId: expense.id!),
                ),
              ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.md),
        child: Row(
          children: [
            if (ink != null) ...[
              Container(width: 3, height: 26, color: ink),
              const SizedBox(width: Space.md),
            ],
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
                    caption,
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
