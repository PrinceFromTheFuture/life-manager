import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:shopping_list/apps/receipts/data/export/expense_exporter.dart';
import 'package:shopping_list/apps/receipts/data/models/expense.dart';
import 'package:shopping_list/apps/receipts/state/providers.dart';
import 'package:shopping_list/apps/receipts/ui/expense_detail_screen.dart';
import 'package:shopping_list/apps/receipts/ui/expense_sheet.dart';
import 'package:shopping_list/apps/receipts/ui/receipts_lists_screen.dart';
import 'package:shopping_list/apps/receipts/ui/stats_screen.dart';
import 'package:shopping_list/core/design/paper_snack.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/design/widgets/perforation.dart';
import 'package:shopping_list/core/util/money.dart';

/// Everything you've spent this month, newest first.
///
/// Scoped to a single month rather than "everything ever" — the month you're
/// looking at is the month you're managing, and the arrows in the header let
/// you step to any other one without leaving the screen.
class ExpenseListScreen extends ConsumerWidget {
  const ExpenseListScreen({super.key});

  Future<void> _exportMonth(BuildContext context, WidgetRef ref) async {
    final scope = await _pickExportScope(context);
    if (scope == null) return;
    try {
      final exporter = ExpenseExporter(ref.read(expenseRepositoryProvider));
      final export = await exporter.buildMonth(
        ref.read(selectedMonthProvider),
        scope: scope,
      );
      if (export.count == 0) {
        if (!context.mounted) return;
        showPaperSnack(
          context,
          message: scope == ExportScope.both
              ? 'Nothing to export this month.'
              : 'Nothing ${scope == ExportScope.business ? 'business' : 'personal'} to export this month.',
        );
        return;
      }
      await exporter.share(export);
    } on Exception catch (e) {
      if (!context.mounted) return;
      showPaperSnack(context, message: 'Could not export: $e');
    }
  }

  Future<ExportScope?> _pickExportScope(BuildContext context) {
    final palette = context.thermal;
    return showDialog<ExportScope>(
      context: context,
      useRootNavigator: false,
      builder: (context) => AlertDialog(
        backgroundColor: palette.paper,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        titleTextStyle:
            Type.display.copyWith(fontSize: 20, color: palette.print),
        contentTextStyle: Type.body.copyWith(color: palette.print),
        title: const Text('Export this month'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final scope in ExportScope.values)
              TextButton(
                onPressed: () => Navigator.of(context).pop(scope),
                style: TextButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  foregroundColor: palette.print,
                ),
                child: Text(scope.label),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.thermal;
    final expenses = ref.watch(monthExpensesProvider);

    return Scaffold(
      backgroundColor: palette.paper,
      appBar: AppBar(
        title: const Text('Receipts'),
        actions: [
          IconButton(
            tooltip: 'Export month',
            icon: const Icon(Icons.ios_share),
            onPressed: () => _exportMonth(context, ref),
          ),
          IconButton(
            tooltip: 'Statistics',
            icon: const Icon(Icons.bar_chart_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const StatsScreen()),
            ),
          ),
          IconButton(
            tooltip: 'Categories and accounts',
            icon: const Icon(Icons.tune),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ReceiptsListsScreen(),
              ),
            ),
          ),
          const SizedBox(width: Space.sm),
        ],
      ),
      body: Column(
        children: [
          const _MonthSelector(),
          const PerforatedRule(),
          Expanded(
            child: expenses.when(
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
          ),
        ],
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

/// The month total plus the two arrows that step between months.
///
/// Doubles as the "which month am I looking at" indicator — there is no
/// separate header for that, because this already says it.
class _MonthSelector extends ConsumerWidget {
  const _MonthSelector();

  Future<void> _jumpToMonth(
    BuildContext context,
    WidgetRef ref,
    DateTime month,
  ) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: month,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year, now.month, now.day),
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'Which month?',
      useRootNavigator: false,
    );
    if (picked == null) return;
    ref.read(selectedMonthProvider.notifier).state =
        DateTime(picked.year, picked.month);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.thermal;
    final month = ref.watch(selectedMonthProvider);
    final total = ref.watch(selectedMonthTotalProvider);
    final now = DateTime.now();
    final isCurrentMonth = month.year == now.year && month.month == now.month;

    return Padding(
      padding:
          const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.lg, Space.md),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Previous month',
            onPressed: () => ref.read(selectedMonthProvider.notifier).state =
                DateTime(month.year, month.month - 1),
          ),
          Expanded(
            child: InkWell(
              onTap: () => _jumpToMonth(context, ref, month),
              child: Column(
                children: [
                  Text(
                    DateFormat('MMMM yyyy').format(month).toUpperCase(),
                    style: Type.eyebrow.copyWith(color: palette.faded),
                  ),
                  const SizedBox(height: Space.xs),
                  Text(
                    total.maybeWhen(data: Money.format, orElse: () => '—'),
                    style: Type.totalDisplay.copyWith(
                      color: palette.print,
                      fontSize: 32,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Next month',
            // A future month is never useful — nothing has been logged there
            // yet, so stepping past "now" would just show an empty screen.
            onPressed: isCurrentMonth
                ? null
                : () => ref.read(selectedMonthProvider.notifier).state =
                    DateTime(month.year, month.month + 1),
          ),
        ],
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
      confirmDismiss: (_) => confirmDeleteExpense(context),
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
                    if (_subtitle(expense) != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        _subtitle(expense)!,
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

  static String? _subtitle(Expense expense) {
    final place = (expense.locationLabel ?? '').trim();
    if (expense.isBusiness && place.isNotEmpty) return 'Business · $place';
    if (expense.isBusiness) return 'Business';
    if (place.isNotEmpty) return place;
    return null;
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
              'No expenses this month.',
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
