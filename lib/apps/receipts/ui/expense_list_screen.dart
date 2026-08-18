import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:shopping_list/apps/receipts/data/export/expense_exporter.dart';
import 'package:shopping_list/apps/receipts/data/models/expense.dart';
import 'package:shopping_list/apps/receipts/data/models/payment_method.dart';
import 'package:shopping_list/apps/receipts/data/receipts_view.dart';
import 'package:shopping_list/apps/receipts/state/providers.dart';
import 'package:shopping_list/apps/receipts/ui/expense_detail_screen.dart';
import 'package:shopping_list/apps/receipts/ui/widgets/margin_code.dart';
import 'package:shopping_list/core/design/paper_snack.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/design/widgets/perforation.dart';
import 'package:shopping_list/core/util/money.dart';

/// Everything you've spent this month, newest first.
///
/// Scoped to a single month rather than "everything ever" — the month you're
/// looking at is the month you're managing, and the arrows in [MonthSelector]
/// let you step to any other one without leaving the screen.
///
/// The app bar, the divider tabs and the Add expense plate all belong to the
/// shell; this is only the roll of slips underneath them.
class SlipsSection extends ConsumerWidget {
  const SlipsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.thermal;
    final expenses = ref.watch(monthExpensesProvider);

    return expenses.when(
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
      data: (items) =>
          items.isEmpty ? const _NoExpenses() : _MonthRoll(expenses: items),
    );
  }
}

/// Shares the month as a spreadsheet, business or personal or both.
///
/// Lives here rather than in the shell because the scope it asks about is a
/// property of this list, not of the app bar it happens to hang from.
Future<void> exportSelectedMonth(BuildContext context, WidgetRef ref) async {
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
      titleTextStyle: Type.display.copyWith(fontSize: 20, color: palette.print),
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

/// The month total plus the two arrows that step between months.
///
/// Doubles as the "which month am I looking at" indicator — there is no
/// separate header for that, because this already says it. Shown under the
/// divider tabs on both SLIPS and STATS, which are the two month-scoped
/// sections.
class MonthSelector extends ConsumerWidget {
  const MonthSelector({super.key});

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

class _MonthRoll extends ConsumerWidget {
  const _MonthRoll({required this.expenses});

  final List<Expense> expenses;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.thermal;
    final sort = ref.watch(receiptsSortProvider);
    // Lenses (to claim, personal, unfiled) live on Statistics. This screen
    // is the month's full roll — cutting it here hid slips behind a chip.
    final shown = ReceiptsView.apply(
      expenses,
      lens: ReceiptsLens.all,
      sort: sort,
    );
    final slipWord = shown.length == 1 ? 'slip' : 'slips';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.lg,
            Space.md,
            Space.lg,
            Space.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${shown.length} $slipWord',
                  style: Type.caption.copyWith(color: palette.faded),
                ),
              ),
              _SortControl(sort: sort),
            ],
          ),
        ),
        const PerforatedRule(),
        Expanded(
          child: _ExpenseRoll(expenses: shown, sort: sort),
        ),
      ],
    );
  }
}

class _SortControl extends ConsumerWidget {
  const _SortControl({required this.sort});

  final ReceiptsSort sort;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.thermal;
    return PopupMenuButton<ReceiptsSort>(
      tooltip: 'Sort',
      padding: EdgeInsets.zero,
      position: PopupMenuPosition.under,
      color: palette.paper,
      surfaceTintColor: Colors.transparent,
      onSelected: (value) =>
          ref.read(receiptsSortProvider.notifier).state = value,
      itemBuilder: (context) => [
        for (final option in ReceiptsSort.values)
          PopupMenuItem(
            value: option,
            child: Text(
              option.label,
              style: Type.body.copyWith(
                color: option == sort ? palette.carbon : palette.print,
              ),
            ),
          ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            sort.label,
            style: Type.caption.copyWith(color: palette.carbon),
          ),
          Icon(Icons.arrow_drop_down, size: 18, color: palette.carbon),
        ],
      ),
    );
  }
}

class _ExpenseRoll extends ConsumerWidget {
  const _ExpenseRoll({required this.expenses, required this.sort});

  final List<Expense> expenses;
  final ReceiptsSort sort;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = switch (sort) {
      ReceiptsSort.newest => _groupByDay(expenses, newestFirst: true),
      ReceiptsSort.oldest => _groupByDay(expenses, newestFirst: false),
      ReceiptsSort.largest => [
          MapEntry('BY AMOUNT', expenses),
        ],
      ReceiptsSort.merchant => _groupByMerchant(expenses),
    };

    // Resolved once for the whole roll rather than per row: every slip needs
    // the same handful of names.
    final methods =
        ref.watch(paymentMethodsProvider).valueOrNull ?? const <PaymentMethod>[];
    final methodNames = {for (final m in methods) m.id: m.label};

    return ListView(
      padding: const EdgeInsets.only(bottom: Space.xxl),
      children: [
        for (final group in groups) ...[
          const SizedBox(height: Space.lg),
          const TearEdge(),
          const SizedBox(height: Space.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.lg),
            child: Text(
              group.key,
              style: Type.eyebrow.copyWith(color: context.thermal.faded),
            ),
          ),
          const SizedBox(height: Space.sm),
          for (final expense in group.value) ...[
            _ExpenseRow(expense: expense, methodNames: methodNames),
            if (expense != group.value.last)
              const PerforatedRule(indent: Space.lg),
          ],
        ],
      ],
    );
  }

  static List<MapEntry<String, List<Expense>>> _groupByDay(
    List<Expense> expenses, {
    required bool newestFirst,
  }) {
    final map = <DateTime, List<Expense>>{};
    for (final e in expenses) {
      final local = e.occurredAt.toLocal();
      final key = DateTime(local.year, local.month, local.day);
      map.putIfAbsent(key, () => []).add(e);
    }
    final keys = map.keys.toList()
      ..sort((a, b) => newestFirst ? b.compareTo(a) : a.compareTo(b));
    return [for (final k in keys) MapEntry(_dayLabel(k), map[k]!)];
  }

  static List<MapEntry<String, List<Expense>>> _groupByMerchant(
    List<Expense> expenses,
  ) {
    final map = <String, List<Expense>>{};
    for (final e in expenses) {
      map.putIfAbsent(e.title, () => []).add(e);
    }
    final keys = map.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return [
      for (final k in keys) MapEntry(k.toUpperCase(), map[k]!),
    ];
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
  const _ExpenseRow({required this.expense, required this.methodNames});

  final Expense expense;
  final Map<int?, String> methodNames;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.thermal;
    final subtitle = _subtitle(expense, methodNames);

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
      confirmDismiss: (_) =>
          confirmDeleteExpense(context, hasReceipt: expense.hasReceipt),
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
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: Type.caption.copyWith(color: palette.faded),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: Space.md),
              // Statement codes live in the numeric column, where a real
              // statement prints them, so the title column carries no extra
              // weight for facts that are true of one slip in fifty.
              if (expense.isAutoCreated) const MarginCode.standingOrder(),
              if (expense.isSplit) MarginCode.installments(expense.installments),
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

  static String? _subtitle(Expense expense, Map<int?, String> methodNames) {
    final parts = <String>[
      if (expense.isAutoCreated) 'Standing',
      if (expense.isBusiness) 'Business',
    ];

    // Where beats what-paid-for-it when both exist: the place is the fact you
    // would use to recognise the slip.
    final place = (expense.locationLabel ?? '').trim();
    if (place.isNotEmpty) {
      parts.add(place);
    } else {
      final method = methodNames[expense.paymentMethodId];
      if (method != null) parts.add(method);
    }

    return parts.isEmpty ? null : parts.join(' · ');
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
