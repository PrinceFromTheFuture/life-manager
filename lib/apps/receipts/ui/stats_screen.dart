import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:shopping_list/apps/receipts/data/models/account.dart';
import 'package:shopping_list/apps/receipts/data/models/category_ink.dart';
import 'package:shopping_list/apps/receipts/data/models/expense.dart';
import 'package:shopping_list/apps/receipts/data/models/expense_category.dart';
import 'package:shopping_list/apps/receipts/data/receipts_view.dart';
import 'package:shopping_list/apps/receipts/state/providers.dart';
import 'package:shopping_list/apps/receipts/ui/expense_detail_screen.dart';
import 'package:shopping_list/apps/receipts/ui/ledger_plate.dart';
import 'package:shopping_list/apps/receipts/ui/stats_charts.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/design/widgets/perforation.dart';
import 'package:shopping_list/core/util/money.dart';

/// Where the money went this month.
///
/// Built without a chart package: ink wells, a till tape of shops, and a
/// day-by-day column. Kind (to claim vs personal) still shares one carbon.
/// Categories each carry their own stamp-pad ink, so the breakdown can be
/// read at a glance.
///
/// A section of the shell rather than a pushed screen: statistics answer a
/// question about the same month the slips list is showing, so making you
/// navigate away from it was always slightly wrong.
class StatsSection extends ConsumerWidget {
  const StatsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.thermal;
    final month = ref.watch(selectedMonthProvider);
    final expensesAsync = ref.watch(monthExpensesProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final accountsAsync = ref.watch(accountsProvider);

    return expensesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text('$e', style: Type.caption.copyWith(color: palette.faded)),
      ),
      data: (expenses) => categoriesAsync.maybeWhen(
        data: (categories) => accountsAsync.maybeWhen(
          data: (accounts) => _StatsBody(
            month: month,
            expenses: expenses,
            categories: categories,
            accounts: accounts,
          ),
          orElse: () => const Center(child: CircularProgressIndicator()),
        ),
        orElse: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _StatsBody extends ConsumerWidget {
  const _StatsBody({
    required this.month,
    required this.expenses,
    required this.categories,
    required this.accounts,
  });

  final DateTime month;
  final List<Expense> expenses;
  final List<ExpenseCategory> categories;
  final List<Account> accounts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.thermal;
    final lens = ref.watch(receiptsLensProvider);
    final previousTotal = ref.watch(previousMonthTotalProvider);
    final lastMonthToDate = ref.watch(lastMonthToDateProvider);

    if (expenses.isEmpty) {
      return const _EmptyStats();
    }

    final lenses = [
      ReceiptsLens.all,
      ReceiptsLens.toClaim,
      ReceiptsLens.personal,
      ReceiptsLens.unfiled,
      if (ReceiptsView.largeCutoff(expenses) != null) ReceiptsLens.large,
    ];
    final shown = ReceiptsView.apply(
      expenses,
      lens: lens,
      sort: ReceiptsSort.newest,
    );
    final fullTotal = ReceiptsView.totalOf(expenses);
    final total = ReceiptsView.totalOf(shown);
    final categoryNames = {for (final c in categories) c.id: c.name};
    final categoryInks = {for (final c in categories) c.id: c.stamp};
    final accountNames = {for (final a in accounts) a.id: a.label};
    final merchants = ReceiptsView.merchantTape(shown);
    final weeks = ReceiptsView.statementWeeks(shown, month);
    final days = ReceiptsView.dailyKind(shown, month);
    final weekend = ReceiptsView.weekendSpend(shown);

    return ListView(
      padding:
          const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, Space.xxl),
      children: [
        LedgerPlateRow<ReceiptsLens>(
          values: lenses,
          selected: lens,
          labelOf: (l) => l.label,
          onSelected: (l) =>
              ref.read(receiptsLensProvider.notifier).state = l,
        ),
        const SizedBox(height: Space.lg),
        Text(
          DateFormat('MMMM yyyy').format(month).toUpperCase(),
          style: Type.eyebrow.copyWith(color: palette.faded),
        ),
        const SizedBox(height: Space.sm),
        Text(
          Money.format(total),
          style: Type.totalDisplay.copyWith(color: palette.print),
        ),
        if (lens != ReceiptsLens.all && total != fullTotal)
          Padding(
            padding: const EdgeInsets.only(top: Space.xs),
            child: Text(
              'of ${Money.format(fullTotal)} this month',
              style: Type.caption.copyWith(color: palette.faded),
            ),
          ),
        previousTotal.maybeWhen(
          data: (previous) {
            final delta = _monthDelta(total, previous, lens);
            if (delta == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: Space.xs),
              child: Text(
                delta,
                style: Type.caption.copyWith(color: palette.faded),
              ),
            );
          },
          orElse: () => const SizedBox.shrink(),
        ),
        lastMonthToDate.maybeWhen(
          data: (prior) {
            final pace = ReceiptsView.pace(
              month: month,
              thisMonth: shown,
              lastMonthToDate: prior,
            );
            final caption = _paceCaption(pace, lens);
            if (caption == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: Space.xs),
              child: Text(
                caption,
                style: Type.caption.copyWith(color: palette.carbon),
              ),
            );
          },
          orElse: () => const SizedBox.shrink(),
        ),
        if (shown.isEmpty) ...[
          const SizedBox(height: Space.xl),
          const PerforatedRule(),
          const SizedBox(height: Space.xl),
          Text(
            lens.empty,
            style: Type.body.copyWith(color: palette.faded),
          ),
        ] else ...[
          const SizedBox(height: Space.lg),
          const PerforatedRule(),
          const SizedBox(height: Space.xl),
          Text('BY KIND', style: Type.eyebrow.copyWith(color: palette.faded)),
          const SizedBox(height: Space.lg),
          _KindBreakdown(expenses: shown, total: total),
          const SizedBox(height: Space.xl),
          const PerforatedRule(),
          const SizedBox(height: Space.xl),
          Text(
            'THE REGISTER',
            style: Type.eyebrow.copyWith(color: palette.faded),
          ),
          const SizedBox(height: Space.sm),
          Text(
            'Twelve months, claimed ink on top.',
            style: Type.caption.copyWith(color: palette.faded),
          ),
          const SizedBox(height: Space.lg),
          const _MonthRegisterSection(),
          const SizedBox(height: Space.xl),
          const PerforatedRule(),
          const SizedBox(height: Space.xl),
          Text(
            'STATEMENT WEEKS',
            style: Type.eyebrow.copyWith(color: palette.faded),
          ),
          const SizedBox(height: Space.sm),
          Text(
            'Days 1–7, 8–14, 15–21, 22–28, then the tail.',
            style: Type.caption.copyWith(color: palette.faded),
          ),
          const SizedBox(height: Space.lg),
          WeekWells(weeks: weeks),
          const SizedBox(height: Space.xl),
          const PerforatedRule(),
          const SizedBox(height: Space.xl),
          Text(
            'THE TAPE',
            style: Type.eyebrow.copyWith(color: palette.faded),
          ),
          const SizedBox(height: Space.sm),
          Text(
            'Who took the month.',
            style: Type.caption.copyWith(color: palette.faded),
          ),
          const SizedBox(height: Space.lg),
          _MerchantTape(merchants: merchants, total: total),
          const SizedBox(height: Space.xl),
          const PerforatedRule(),
          const SizedBox(height: Space.xl),
          Text(
            'BY CATEGORY',
            style: Type.eyebrow.copyWith(color: palette.faded),
          ),
          const SizedBox(height: Space.lg),
          _CategoryBreakdown(
            expenses: shown,
            categoryNames: categoryNames,
            categoryInks: categoryInks,
          ),
          if (_hasPaidWith(shown)) ...[
            const SizedBox(height: Space.xl),
            const PerforatedRule(),
            const SizedBox(height: Space.xl),
            Text(
              'PAID WITH',
              style: Type.eyebrow.copyWith(color: palette.faded),
            ),
            const SizedBox(height: Space.lg),
            _PaidWithBreakdown(
              expenses: shown,
              accountNames: accountNames,
            ),
          ],
          const _CommittedCycles(),
          const SizedBox(height: Space.xl),
          const PerforatedRule(),
          const SizedBox(height: Space.xl),
          Text('BY DAY', style: Type.eyebrow.copyWith(color: palette.faded)),
          const SizedBox(height: Space.sm),
          Text(
            weekend > 0 && total > 0
                ? 'Friday and Saturday took ${((weekend / total) * 100).round()}% · personal underneath, business on top'
                : 'Personal underneath, business on top.',
            style: Type.caption.copyWith(color: palette.faded),
          ),
          const SizedBox(height: Space.lg),
          StackedDailySpend(
            month: month,
            days: days,
            expenses: shown,
            onOpenExpense: (expense) {
              if (expense.id == null) return;
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      ExpenseDetailScreen(expenseId: expense.id!),
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  static bool _hasPaidWith(List<Expense> expenses) =>
      expenses.any((e) => e.paymentMethodId != null || e.accountId != null);

  static String? _monthDelta(int current, int previous, ReceiptsLens lens) {
    if (previous == 0 || lens != ReceiptsLens.all) return null;
    final change = ((current - previous) / previous * 100).round();
    if (change == 0) return 'Same as last month';
    final direction = change > 0 ? 'up' : 'down';
    return '${change.abs()}% $direction on last month';
  }

  static String? _paceCaption(MonthPace pace, ReceiptsLens lens) {
    if (pace.monthComplete) return null;
    if (lens != ReceiptsLens.all) return null;
    final parts = <String>[
      'Day ${pace.day} of ${pace.daysInMonth}',
    ];
    if (pace.lastMonthToDate > 0) {
      final d = pace.deltaToDate;
      if (d == 0) {
        parts.add('even with last month by now');
      } else if (d > 0) {
        parts.add('${Money.format(d)} ahead of last month by now');
      } else {
        parts.add('${Money.format(-d)} behind last month by now');
      }
    }
    parts.add('on course for ${Money.format(pace.projected)}');
    return parts.join(' · ');
  }
}

class _EmptyStats extends StatelessWidget {
  const _EmptyStats();

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
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
              style: Type.display.copyWith(color: palette.print, fontSize: 26),
            ),
            const SizedBox(height: Space.md),
            Text(
              'Statistics fill in once you have logged an expense this month.',
              style: Type.body.copyWith(color: palette.faded),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthRegisterSection extends ConsumerWidget {
  const _MonthRegisterSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.thermal;
    final month = ref.watch(selectedMonthProvider);
    final history = ref.watch(kindTotalsByMonthProvider);

    return history.maybeWhen(
      data: (months) {
        final filled = ReceiptsView.registerMonths(months);
        if (filled.every((m) => m.totalMinor == 0)) {
          return Text(
            'No months to compare yet.',
            style: Type.caption.copyWith(color: palette.faded),
          );
        }
        return MonthRegister(
          months: filled,
          selected: month,
          onSelect: (picked) =>
              ref.read(selectedMonthProvider.notifier).state = picked,
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

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
        InkRun(
          label: 'To claim',
          amountMinor: business,
          fraction: business / max,
          ink: palette.carbon,
        ),
        const SizedBox(height: Space.md),
        InkRun(
          label: 'Personal',
          amountMinor: personal,
          fraction: personal / max,
          ink: palette.carbon.withValues(alpha: 0.45),
        ),
        if (total > 0 && business > 0) ...[
          const SizedBox(height: Space.sm),
          Text(
            '${((business / total) * 100).round()}% of this view is to claim',
            style: Type.caption.copyWith(color: palette.faded),
          ),
        ],
      ],
    );
  }
}

class _MerchantTape extends StatelessWidget {
  const _MerchantTape({required this.merchants, required this.total});

  final List<MerchantTotal> merchants;
  final int total;

  @override
  Widget build(BuildContext context) {
    if (merchants.isEmpty) return const SizedBox.shrink();
    final top = merchants.take(8).toList();
    final max = top.first.amountMinor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final row in top) ...[
          InkRun(
            label: row.name,
            amountMinor: row.amountMinor,
            fraction: row.amountMinor / max,
            detail: row.count == 1
                ? (total > 0
                    ? '${((row.amountMinor / total) * 100).round()}% of this view'
                    : null)
                : '${row.count} slips'
                    '${total > 0 ? ' · ${((row.amountMinor / total) * 100).round()}%' : ''}',
          ),
          const SizedBox(height: Space.md),
        ],
      ],
    );
  }
}

class _CategoryBreakdown extends StatelessWidget {
  const _CategoryBreakdown({
    required this.expenses,
    required this.categoryNames,
    required this.categoryInks,
  });

  final List<Expense> expenses;
  final Map<int?, String> categoryNames;
  final Map<int?, CategoryInk> categoryInks;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    final brightness = Theme.of(context).brightness;
    final totals = <int?, int>{};
    for (final e in expenses) {
      totals[e.categoryId] = (totals[e.categoryId] ?? 0) + e.amountMinor;
    }
    final sorted = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (sorted.isEmpty) return const SizedBox.shrink();
    final max = sorted.first.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in sorted) ...[
          InkRun(
            label: categoryNames[entry.key] ?? 'Unfiled',
            amountMinor: entry.value,
            fraction: entry.value / max,
            ink: categoryInks[entry.key]?.of(brightness) ?? palette.faded,
          ),
          const SizedBox(height: Space.md),
        ],
      ],
    );
  }
}

/// Split by payment method, falling back to the account for slips logged
/// before methods existed.
class _PaidWithBreakdown extends ConsumerWidget {
  const _PaidWithBreakdown({
    required this.expenses,
    required this.accountNames,
  });

  final List<Expense> expenses;
  final Map<int?, String> accountNames;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final methods = ref.watch(paymentMethodsProvider).valueOrNull ?? const [];
    final methodNames = {for (final m in methods) m.id: m.label};

    final totals = <String, int>{};
    for (final e in expenses) {
      final name = methodNames[e.paymentMethodId] ??
          accountNames[e.accountId] ??
          'Unassigned';
      totals[name] = (totals[name] ?? 0) + e.amountMinor;
    }

    final sorted = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (sorted.isEmpty) return const SizedBox.shrink();
    final max = sorted.first.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in sorted) ...[
          InkRun(
            label: entry.key,
            amountMinor: entry.value,
            fraction: entry.value / max,
          ),
          const SizedBox(height: Space.md),
        ],
      ],
    );
  }
}

/// What the cards are carrying right now.
///
/// Deliberately not month-scoped like everything above it: a statement cycle
/// straddles two calendar months, and pretending otherwise would show you a
/// number no card issuer will ever bill you for. Hidden entirely when nothing
/// is on credit, which for most people is most of the time.
class _CommittedCycles extends ConsumerWidget {
  const _CommittedCycles();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.thermal;
    final standings = ref.watch(accountStandingsProvider).valueOrNull;
    if (standings == null) return const SizedBox.shrink();

    final rows = <MapEntry<String, int>>[];
    for (final standing in standings) {
      for (final method in standing.methods) {
        final committed = standing.committed[method.id] ?? 0;
        if (committed > 0) rows.add(MapEntry(method.label, committed));
      }
    }
    if (rows.isEmpty) return const SizedBox.shrink();

    rows.sort((a, b) => b.value.compareTo(a.value));
    final max = rows.first.value;
    final total = rows.fold(0, (sum, row) => sum + row.value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: Space.xl),
        const PerforatedRule(),
        const SizedBox(height: Space.xl),
        Text(
          'ON THE CARDS',
          style: Type.eyebrow.copyWith(color: palette.faded),
        ),
        const SizedBox(height: Space.sm),
        Text(
          '${Money.format(total)} charged and not yet collected.',
          style: Type.caption.copyWith(color: palette.faded),
        ),
        const SizedBox(height: Space.lg),
        for (final row in rows) ...[
          InkRun(
            label: row.key,
            amountMinor: row.value,
            fraction: row.value / max,
          ),
          const SizedBox(height: Space.md),
        ],
      ],
    );
  }
}
