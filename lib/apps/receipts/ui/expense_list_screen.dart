import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:shopping_list/apps/receipts/data/models/expense.dart';
import 'package:shopping_list/apps/receipts/state/providers.dart';
import 'package:shopping_list/apps/receipts/ui/expense_detail_screen.dart';
import 'package:shopping_list/apps/receipts/ui/expense_sheet.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/design/widgets/perforation.dart';
import 'package:shopping_list/core/util/money.dart';

/// Everything you've spent, newest first.
class ExpenseListScreen extends ConsumerWidget {
  const ExpenseListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.thermal;
    final expenses = ref.watch(expensesProvider);

    return Scaffold(
      backgroundColor: palette.paper,
      appBar: AppBar(title: const Text('Receipts')),
      body: expenses.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(Space.lg),
            child: Text(
              '$e',
              style: Type.caption.copyWith(color: palette.faded),
            ),
          ),
        ),
        data: (items) => items.isEmpty
            ? const _NoExpenses()
            : _ExpenseRoll(expenses: items),
      ),
      bottomNavigationBar: Container(
        color: palette.paper,
        padding: EdgeInsets.fromLTRB(
          Space.lg,
          Space.md,
          Space.lg,
          Space.md + MediaQuery.paddingOf(context).bottom,
        ),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => ExpenseSheet.open(context),
            icon: const Icon(Icons.photo_camera_outlined, size: 20),
            // Names the action by what it actually does first.
            label: const Text('Add expense'),
          ),
        ),
      ),
    );
  }
}

class _ExpenseRoll extends ConsumerWidget {
  const _ExpenseRoll({required this.expenses});

  final List<Expense> expenses;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = _groupByDay(expenses);

    return ListView(
      padding: const EdgeInsets.only(bottom: Space.xxl),
      children: [
        const _MonthTotal(),
        for (final day in days) ...[
          const SizedBox(height: Space.lg),
          const TearEdge(),
          const SizedBox(height: Space.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.lg),
            child: Text(
              _dayLabel(day.key),
              style: Type.eyebrow.copyWith(color: context.thermal.faded),
            ),
          ),
          const SizedBox(height: Space.sm),
          for (final expense in day.value) ...[
            _ExpenseRow(expense: expense),
            if (expense != day.value.last)
              const PerforatedRule(indent: Space.lg),
          ],
        ],
      ],
    );
  }

  static List<MapEntry<DateTime, List<Expense>>> _groupByDay(
    List<Expense> expenses,
  ) {
    final map = <DateTime, List<Expense>>{};
    for (final e in expenses) {
      final local = e.occurredAt.toLocal();
      final key = DateTime(local.year, local.month, local.day);
      map.putIfAbsent(key, () => []).add(e);
    }
    final keys = map.keys.toList()..sort((a, b) => b.compareTo(a));
    return [for (final k in keys) MapEntry(k, map[k]!)];
  }

  static String _dayLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final difference = today.difference(date).inDays;
    if (difference == 0) return 'TODAY';
    if (difference == 1) return 'YESTERDAY';
    if (difference < 7) return DateFormat('EEEE').format(date).toUpperCase();
    return DateFormat('d MMM yyyy').format(date).toUpperCase();
  }
}

/// The number this whole app exists to surface.
class _MonthTotal extends ConsumerWidget {
  const _MonthTotal();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.thermal;
    final total = ref.watch(monthToDateProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat('MMMM').format(DateTime.now()).toUpperCase(),
            style: Type.eyebrow.copyWith(color: palette.faded),
          ),
          const SizedBox(height: Space.sm),
          Text(
            total.maybeWhen(
              data: Money.format,
              orElse: () => '—',
            ),
            style: Type.totalDisplay.copyWith(color: palette.print),
          ),
        ],
      ),
    );
  }
}

class _ExpenseRow extends ConsumerWidget {
  const _ExpenseRow({required this.expense});

  final Expense expense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.thermal;

    return Dismissible(
      key: ValueKey('expense-${expense.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: palette.paperShade,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: Space.lg),
        child: Icon(Icons.delete_outline, color: palette.faded),
      ),
      // Unlike a list item, this deletes a photo too — so it asks first rather
      // than offering an undo it could not honour.
      confirmDismiss: (_) => showDialog<bool>(
        context: context,
        // Keeps the dialog inside this app's ink; the root navigator is above
        // the InkScope.
        useRootNavigator: false,
        builder: (context) => AlertDialog(
          backgroundColor: palette.paper,
          surfaceTintColor: Colors.transparent,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          titleTextStyle:
              Type.display.copyWith(fontSize: 20, color: palette.print),
          contentTextStyle: Type.body.copyWith(color: palette.print),
          title: const Text('Delete this expense?'),
          content: const Text(
            'The amount and the receipt photo are deleted for good.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Keep'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('Delete'),
            ),
          ],
        ),
      ),
      onDismissed: (_) =>
          ref.read(expensesProvider.notifier).remove(expense.id!),
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ExpenseDetailScreen(expenseId: expense.id!),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.lg,
            vertical: Space.md + 2,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      expense.title,
                      style: Type.item.copyWith(color: palette.print),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if ((expense.locationLabel ?? '').isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        expense.locationLabel!,
                        style: Type.caption.copyWith(color: palette.faded),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
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
      ),
    );
  }
}

class _NoExpenses extends StatelessWidget {
  const _NoExpenses();

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
              'No expenses yet.',
              style: Type.display.copyWith(color: palette.print, fontSize: 28),
            ),
            const SizedBox(height: Space.md),
            Text(
              'Photograph a receipt and it lands here — what you paid, where, '
              'and on what.',
              style: Type.body.copyWith(color: palette.faded),
            ),
          ],
        ),
      ),
    );
  }
}
