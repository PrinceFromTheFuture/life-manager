import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shopping_list/apps/receipts/data/models/recurring_rule.dart';
import 'package:shopping_list/apps/receipts/data/receipts_view.dart';
import 'package:shopping_list/apps/receipts/data/recurring_view.dart';
import 'package:shopping_list/apps/receipts/state/providers.dart';
import 'package:shopping_list/apps/receipts/ui/accounts/income_sheet.dart';
import 'package:shopping_list/apps/receipts/ui/expense_sheet.dart';
import 'package:shopping_list/apps/receipts/ui/recurring/recurring_sheet.dart';
import 'package:shopping_list/apps/receipts/ui/stats_charts.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/design/widgets/app_icon.dart';
import 'package:shopping_list/core/design/widgets/perforation.dart';
import 'package:shopping_list/core/util/money.dart';

/// Recurring payments. Templates, not a ledger.
///
/// Tap logs a slip prefilled from the template. Hold opens the template
/// itself. The page never writes money on its own.
class RecurringSection extends ConsumerStatefulWidget {
  const RecurringSection({super.key});

  @override
  ConsumerState<RecurringSection> createState() => _RecurringSectionState();
}

class _RecurringSectionState extends ConsumerState<RecurringSection> {
  final _pages = PageController();
  var _page = 0;
  int? _donutId;
  var _donutPinned = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    final rules = ref.watch(recurringRulesProvider);
    final categories = ref.watch(categoriesProvider).valueOrNull ?? const [];

    return rules.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(Space.lg),
          child: Text('$e', style: Type.caption.copyWith(color: palette.faded)),
        ),
      ),
      data: (items) {
        if (items.isEmpty) return const _NothingRecurring();

        final brightness = Theme.of(context).brightness;
        final names = <int, String>{
          for (final c in categories)
            if (c.id != null) c.id!: c.name,
        };
        final inks = <int?, Color>{
          null: palette.faded,
          for (final c in categories) c.id: c.stamp.of(brightness),
        };
        final groups = RecurringView.grouped(items, categoryNames: names);
        final totals = RecurringView.categoryTotals(items);
        final donutId = _donutPinned
            ? _donutId
            : (totals.isEmpty ? null : totals.first.categoryId);
        final slices = [
          for (final row in totals)
            DonutSlice(
              categoryId: row.categoryId,
              name: names[row.categoryId] ?? 'Unfiled',
              amountMinor: row.amountMinor,
              ink: inks[row.categoryId] ?? palette.faded,
            ),
        ];
        final out = RecurringView.expenseTotal(items);
        final incoming = RecurringView.incomeTotal(items);

        return ListView(
          padding: const EdgeInsets.only(bottom: Space.xxl),
          children: [
            const SizedBox(height: Space.lg),
            SizedBox(
              height: 236,
              child: PageView(
                controller: _pages,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.lg),
                    child: _ChartCard(
                      eyebrow: 'BY KIND',
                      child: CategoryDonut(
                        slices: slices,
                        totalMinor: out,
                        selectedId: donutId,
                        onSelect: (id) => setState(() {
                          _donutId = id;
                          _donutPinned = true;
                        }),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.lg),
                    child: _ChartCard(
                      eyebrow: 'BY DAY',
                      child: _DueBlotter(
                        stacks: RecurringView.dayStacks(items),
                        inks: inks,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.lg),
                    child: _ChartCard(
                      eyebrow: 'EACH MONTH',
                      child: _FlowSplit(leaves: out, arrives: incoming),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Space.sm),
            _PagerDots(count: 3, index: _page),
            const SizedBox(height: Space.md),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.lg),
              child: Text(
                'Tap to log this month. Hold to edit.',
                style: Type.caption.copyWith(color: palette.faded),
              ),
            ),
            for (final group in groups) _CategoryGroup(group: group, inks: inks),
          ],
        );
      },
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.eyebrow, required this.child});

  final String eyebrow;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(eyebrow, style: Type.eyebrow.copyWith(color: palette.faded)),
        const SizedBox(height: Space.sm),
        Expanded(child: child),
      ],
    );
  }
}

class _PagerDots extends StatelessWidget {
  const _PagerDots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Container(
            width: i == index ? 10 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == index ? palette.carbon : palette.perforation,
              borderRadius: Radii.control,
            ),
          ),
        ],
      ],
    );
  }
}

/// The month as a punch card. Each cell is a day of the month; ink means
/// something is usually paid that day. The shape of the month is the point.
class _DueBlotter extends StatelessWidget {
  const _DueBlotter({required this.stacks, required this.inks});

  final List<List<CategorySlice>> stacks;
  final Map<int?, Color> inks;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 3.0;
        final cell = (constraints.maxWidth - gap * 6) / 7;
        return Column(
          children: [
            for (var row = 0; row < 5; row++) ...[
              if (row > 0) const SizedBox(height: gap),
              Row(
                children: [
                  for (var col = 0; col < 7; col++) ...[
                    if (col > 0) const SizedBox(width: gap),
                    SizedBox(
                      width: cell,
                      height: cell.clamp(22.0, 34.0),
                      child: _DayPunch(
                        day: row * 7 + col + 1,
                        slices: row * 7 + col + 1 > 31
                            ? const []
                            : stacks[row * 7 + col],
                        inks: inks,
                        faded: palette.faded,
                        paperShade: palette.paperShade,
                        perforation: palette.perforation,
                        print: palette.print,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

class _DayPunch extends StatelessWidget {
  const _DayPunch({
    required this.day,
    required this.slices,
    required this.inks,
    required this.faded,
    required this.paperShade,
    required this.perforation,
    required this.print,
  });

  final int day;
  final List<CategorySlice> slices;
  final Map<int?, Color> inks;
  final Color faded;
  final Color paperShade;
  final Color perforation;
  final Color print;

  @override
  Widget build(BuildContext context) {
    if (day > 31) return const SizedBox.expand();
    final due = slices.isNotEmpty;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: paperShade,
        border: Border.all(color: perforation, width: 1),
      ),
      child: Stack(
        children: [
          Center(
            child: Text(
              '$day',
              style: Type.mono.copyWith(
                color: due ? print : faded,
                fontSize: 9,
              ),
            ),
          ),
          if (due)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 3,
              child: Row(
                children: [
                  for (final slice in slices)
                    Expanded(
                      flex: slice.amountMinor,
                      child: ColoredBox(
                        color: inks[slice.categoryId] ?? faded,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _FlowSplit extends StatelessWidget {
  const _FlowSplit({required this.leaves, required this.arrives});

  final int leaves;
  final int arrives;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    return Row(
      children: [
        Expanded(
          child: _FlowColumn(
            eyebrow: 'LEAVES',
            amountMinor: leaves,
            ink: palette.print,
          ),
        ),
        Container(width: 1, color: palette.perforation),
        Expanded(
          child: _FlowColumn(
            eyebrow: 'ARRIVES',
            amountMinor: arrives,
            ink: palette.carbon,
            signed: true,
          ),
        ),
      ],
    );
  }
}

class _FlowColumn extends StatelessWidget {
  const _FlowColumn({
    required this.eyebrow,
    required this.amountMinor,
    required this.ink,
    this.signed = false,
  });

  final String eyebrow;
  final int amountMinor;
  final Color ink;
  final bool signed;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    final label = signed && amountMinor > 0
        ? '+${Money.format(amountMinor)}'
        : Money.format(amountMinor);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(eyebrow, style: Type.eyebrow.copyWith(color: palette.faded)),
          const SizedBox(height: Space.sm),
          Text(
            label,
            style: Type.monoBold.copyWith(color: ink, fontSize: 22),
          ),
        ],
      ),
    );
  }
}

class _CategoryGroup extends StatelessWidget {
  const _CategoryGroup({required this.group, required this.inks});

  final RecurringGroup group;
  final Map<int?, Color> inks;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    final ink = group.isIncoming
        ? palette.carbon
        : (inks[group.categoryId] ?? palette.faded);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: Space.lg),
        const TearEdge(),
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.lg, 0),
          child: Row(
            children: [
              Container(width: 8, height: 8, color: ink),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Text(
                  group.name.toUpperCase(),
                  style: Type.eyebrow.copyWith(color: palette.faded),
                ),
              ),
              Text(
                group.isIncoming
                    ? '+${Money.format(group.totalMinor)}'
                    : Money.format(group.totalMinor),
                style: Type.mono.copyWith(color: palette.faded, fontSize: 12),
              ),
            ],
          ),
        ),
        for (var i = 0; i < group.rules.length; i++) ...[
          _RuleRow(
            rule: group.rules[i],
            categoryInk: group.isIncoming ? null : inks[group.categoryId],
          ),
          if (i != group.rules.length - 1) const PerforatedRule(indent: Space.lg),
        ],
      ],
    );
  }
}

class _RuleRow extends ConsumerWidget {
  const _RuleRow({required this.rule, required this.categoryInk});

  final RecurringRule rule;
  final Color? categoryInk;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.thermal;
    final methods = ref.watch(paymentMethodsProvider).valueOrNull ?? const [];
    final accounts = ref.watch(accountsProvider).valueOrNull ?? const [];
    final linked = ref.watch(recurringLinkedThisMonthProvider).valueOrNull ??
        const <int>{};
    final logged = rule.id != null && linked.contains(rule.id);

    final paidWith = rule.isIncome
        ? accounts.where((a) => a.id == rule.accountId).firstOrNull?.name
        : methods.where((m) => m.id == rule.paymentMethodId).firstOrNull?.label;

    return Dismissible(
      key: ValueKey('rule-${rule.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: palette.paperShade,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: Space.lg),
        child: AppIcon(SolarIcons.TrashBinMinimalistic, color: palette.faded),
      ),
      confirmDismiss: (_) => _confirmDelete(context),
      onDismissed: (_) =>
          ref.read(financeControllerProvider).deleteRule(rule.id!),
      child: InkWell(
        onTap: () => _log(context),
        onLongPress: () {
          HapticFeedback.mediumImpact();
          RecurringSheet.open(context, existing: rule);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.lg,
            vertical: Space.md + 2,
          ),
          child: Row(
            children: [
              if (categoryInk != null) ...[
                Container(width: 3, height: 26, color: categoryInk),
                const SizedBox(width: Space.md),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      rule.name,
                      style: Type.item.copyWith(color: palette.print),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (paidWith != null) paidWith,
                        'the ${_ordinal(rule.dayOfMonth)}',
                      ].join(' · '),
                      style: Type.caption.copyWith(color: palette.faded),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Space.md),
              Text(
                logged ? 'IN' : 'MISSING',
                style: Type.eyebrow.copyWith(
                  color: logged ? palette.faded : palette.scorch,
                ),
              ),
              const SizedBox(width: Space.sm),
              Text(
                rule.isIncome
                    ? '+${Money.format(rule.amountMinor)}'
                    : Money.format(rule.amountMinor),
                style: Type.monoBold.copyWith(color: palette.print),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _log(BuildContext context) {
    if (rule.isIncome) {
      IncomeSheet.open(context, fromRule: rule);
    } else {
      ExpenseSheet.open(context, fromRule: rule);
    }
  }

  Future<bool?> _confirmDelete(BuildContext context) {
    final palette = context.thermal;
    return showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (context) => AlertDialog(
        backgroundColor: palette.paper,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Text('Delete this recurring payment?'),
        content: const Text(
          'It leaves the list. Slips you already logged stay.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  static String _ordinal(int day) {
    final suffix = switch (day) {
      1 || 21 || 31 => 'st',
      2 || 22 => 'nd',
      3 || 23 => 'rd',
      _ => 'th',
    };
    return '$day$suffix';
  }
}

class _NothingRecurring extends StatelessWidget {
  const _NothingRecurring();

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
              'Nothing recurring yet.',
              style: Type.display.copyWith(color: palette.print, fontSize: 28),
            ),
            const SizedBox(height: Space.md),
            Text(
              'Rent, gym, insurance — the payments you make most months. '
              'Tap one later to log it. Nothing writes itself.',
              style: Type.body.copyWith(color: palette.faded),
            ),
          ],
        ),
      ),
    );
  }
}
