import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shopping_list/apps/receipts/data/models/recurring_rule.dart';
import 'package:shopping_list/apps/receipts/state/providers.dart';
import 'package:shopping_list/apps/receipts/ui/standing/standing_sheet.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/design/widgets/perforation.dart';
import 'package:shopping_list/core/util/money.dart';

/// The things that happen without you.
///
/// Grouped by the day of the month they land on, because that is how anyone
/// actually holds them in their head — the 1st is rent, the 10th is the gym.
/// The day is a large mono numeral in the left gutter, and the rows hang off
/// it, so the shape of your month is legible before you read a single word.
class StandingSection extends ConsumerWidget {
  const StandingSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.thermal;
    final rules = ref.watch(recurringRulesProvider);

    return rules.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(Space.lg),
          child: Text('$e', style: Type.caption.copyWith(color: palette.faded)),
        ),
      ),
      data: (items) {
        if (items.isEmpty) return const _NothingStanding();

        final byDay = <int, List<RecurringRule>>{};
        for (final rule in items) {
          byDay.putIfAbsent(rule.dayOfMonth, () => []).add(rule);
        }
        final days = byDay.keys.toList()..sort();

        return ListView(
          padding: const EdgeInsets.only(bottom: Space.xxl),
          children: [
            for (final day in days)
              _DayGroup(day: day, rules: byDay[day]!),
          ],
        );
      },
    );
  }
}

class _DayGroup extends StatelessWidget {
  const _DayGroup({required this.day, required this.rules});

  final int day;
  final List<RecurringRule> rules;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: Space.lg),
        const TearEdge(),
        const SizedBox(height: Space.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The spine. Fixed width so every group's rows align, however many
            // digits the day has.
            SizedBox(
              width: 56,
              child: Padding(
                padding: const EdgeInsets.only(top: Space.md),
                child: Text(
                  '$day',
                  textAlign: TextAlign.center,
                  style: Type.mono.copyWith(
                    color: palette.faded,
                    fontSize: 26,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  for (final rule in rules) ...[
                    _RuleRow(rule: rule),
                    if (rule != rules.last)
                      const PerforatedRule(indent: Space.md),
                  ],
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RuleRow extends ConsumerWidget {
  const _RuleRow({required this.rule});

  final RecurringRule rule;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.thermal;
    // A paused rule fades whole rather than hiding behind a menu: it is still
    // part of your month, it is just not running.
    final ink = rule.active ? palette.print : palette.faded;
    final methods = ref.watch(paymentMethodsProvider).valueOrNull ?? const [];
    final accounts = ref.watch(accountsProvider).valueOrNull ?? const [];

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
        child: Icon(Icons.delete_outline, color: palette.faded),
      ),
      confirmDismiss: (_) => _confirmDelete(context),
      onDismissed: (_) =>
          ref.read(financeControllerProvider).deleteRule(rule.id!),
      child: InkWell(
        onTap: () => StandingSheet.open(context, existing: rule),
        onLongPress: () => ref.read(financeControllerProvider).setRuleActive(
              rule.id!,
              active: !rule.active,
            ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, Space.md, Space.lg, Space.md),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rule.name,
                      style: Type.item.copyWith(color: ink),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (paidWith != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        paidWith,
                        style: Type.caption.copyWith(color: palette.faded),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (!rule.active)
                Padding(
                  padding: const EdgeInsets.only(right: Space.sm),
                  child: Text(
                    'PAUSED',
                    style: Type.eyebrow.copyWith(color: palette.faded),
                  ),
                ),
              Text(
                rule.isIncome
                    ? '+${Money.format(rule.amountMinor)}'
                    : Money.format(rule.amountMinor),
                style: Type.monoBold.copyWith(color: ink),
              ),
            ],
          ),
        ),
      ),
    );
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
        title: const Text('Delete this standing order?'),
        content: const Text(
          'It stops writing itself into the month. Everything it has already '
          'written stays.',
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
}

class _NothingStanding extends StatelessWidget {
  const _NothingStanding();

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
              'Nothing standing yet.',
              style: Type.display.copyWith(color: palette.print, fontSize: 28),
            ),
            const SizedBox(height: Space.md),
            Text(
              'A standing order writes itself into the month on the day you '
              'set. Rent, gym, insurance.',
              style: Type.body.copyWith(color: palette.faded),
            ),
          ],
        ),
      ),
    );
  }
}
