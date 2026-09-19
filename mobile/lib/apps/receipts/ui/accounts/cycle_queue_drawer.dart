import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:shopping_list/apps/receipts/data/finance/statement_cycle.dart';
import 'package:shopping_list/apps/receipts/data/models/expense.dart';
import 'package:shopping_list/apps/receipts/data/models/payment_method.dart';
import 'package:shopping_list/apps/receipts/state/providers.dart';
import 'package:shopping_list/apps/receipts/ui/expense_detail_screen.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/design/widgets/inset_drawer.dart';
import 'package:shopping_list/core/design/widgets/perforation.dart';
import 'package:shopping_list/core/util/money.dart';

/// The charges on a credit card that have not left the account yet.
Future<void> openCycleQueueDrawer(
  BuildContext context, {
  required PaymentMethod method,
}) {
  return showInsetDrawer<void>(
    context: context,
    primary: (_) => _CycleQueueDrawer(method: method),
  );
}

class _CycleQueueDrawer extends ConsumerWidget {
  const _CycleQueueDrawer({required this.method});

  final PaymentMethod method;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.thermal;
    final statementDay = method.statementDay;
    if (statementDay == null || method.id == null) {
      return const SizedBox.shrink();
    }

    final cycle = StatementCycles.open(DateTime.now(), statementDay);
    final charges = ref.watch(_cycleChargesProvider((
      methodId: method.id!,
      from: cycle.start,
      to: cycle.end,
    )));

    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.lg, 0),
      child: charges.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(Space.xl),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Text('$e', style: Type.caption.copyWith(color: palette.faded)),
        data: (items) {
          final total = items.fold<int>(0, (sum, e) => sum + e.amountMinor);
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                method.label,
                style: Type.display.copyWith(fontSize: 22, color: palette.print),
              ),
              const SizedBox(height: Space.xs),
              Text(
                items.isEmpty
                    ? 'Nothing waiting to settle.'
                    : '${Money.format(total)} waiting · settles ${DateFormat('d MMM').format(cycle.settlesOn)}',
                style: Type.caption.copyWith(color: palette.faded),
              ),
              const SizedBox(height: Space.lg),
              if (items.isEmpty)
                Text(
                  'Charges this cycle land here until the statement day, then '
                  'they leave the account in one line.',
                  style: Type.body.copyWith(color: palette.faded),
                )
              else
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.45,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const PerforatedRule(),
                    itemBuilder: (context, i) => _ChargeRow(expense: items[i]),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

typedef _CycleWindow = ({int methodId, DateTime from, DateTime to});

final _cycleChargesProvider =
    FutureProvider.autoDispose.family<List<Expense>, _CycleWindow>(
  (ref, window) {
    ref.watch(expensesProvider);
    return ref.watch(expenseRepositoryProvider).chargedToMethod(
          paymentMethodId: window.methodId,
          from: window.from,
          to: window.to,
        );
  },
);

class _ChargeRow extends StatelessWidget {
  const _ChargeRow({required this.expense});

  final Expense expense;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ExpenseDetailScreen(expenseId: expense.id!),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.md),
        child: Row(
          children: [
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
                    DateFormat('d MMM').format(expense.occurredAt).toUpperCase(),
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
