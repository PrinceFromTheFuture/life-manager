import 'package:shopping_list/apps/receipts/data/expense_repository.dart';
import 'package:shopping_list/apps/receipts/data/finance/recurrence.dart';
import 'package:shopping_list/apps/receipts/data/finance/statement_cycle.dart';
import 'package:shopping_list/apps/receipts/data/models/expense.dart';
import 'package:shopping_list/apps/receipts/data/models/income.dart';
import 'package:shopping_list/apps/receipts/data/models/recurring_rule.dart';

/// What one sweep did, so the app can say so instead of rows appearing from
/// nowhere.
class SweepResult {
  const SweepResult({
    this.ordersPosted = 0,
    this.statementsSettled = 0,
  });

  final int ordersPosted;
  final int statementsSettled;

  bool get isEmpty => ordersPosted == 0 && statementsSettled == 0;

  /// One line, in the quietest channel the app has. Nothing here earns the
  /// print ceremony — that belongs to a transaction you made yourself.
  String? get message {
    if (isEmpty) return null;

    final parts = <String>[];
    if (ordersPosted > 0) {
      parts.add(
        ordersPosted == 1
            ? '1 standing order posted.'
            : '$ordersPosted standing orders posted.',
      );
    }
    if (statementsSettled > 0) {
      parts.add(
        statementsSettled == 1
            ? '1 statement settled.'
            : '$statementsSettled statements settled.',
      );
    }
    return parts.join(' ');
  }
}

/// Writes what should already have happened.
///
/// Runs once when the receipts shell mounts. Two jobs: post the standing orders
/// that came due since the last sweep, and settle the credit cycles that have
/// closed since the last statement. Both are idempotent — the first through
/// `last_run_on`, the second through the settlement entry itself — so running
/// this on every launch is safe and running it twice writes nothing.
class RecurringMaterializer {
  const RecurringMaterializer(this._repo);

  final ExpenseRepository _repo;

  Future<SweepResult> run({DateTime? now}) async {
    final at = now ?? DateTime.now();
    final posted = await _postDueRules(at);
    final settled = await _settleClosedCycles(at);
    return SweepResult(ordersPosted: posted, statementsSettled: settled);
  }

  Future<int> _postDueRules(DateTime now) async {
    final rules = await _repo.recurringRules();
    var posted = 0;

    for (final rule in rules) {
      final due = Recurrence.datesDue(rule, now: now);
      if (due.isEmpty) continue;

      for (final date in due) {
        if (rule.isIncome) {
          await _repo.addIncome(_incomeFrom(rule, date));
        } else {
          await _repo.createWithoutReceipt(_expenseFrom(rule, date));
        }
        posted++;
      }

      await _repo.recurring.markRun(rule.id!, due.last);
    }

    return posted;
  }

  Future<int> _settleClosedCycles(DateTime now) async {
    final methods = await _repo.paymentMethods();
    var settled = 0;

    for (final method in methods) {
      final statementDay = method.statementDay;
      if (!method.isCredit || statementDay == null || method.isArchived) {
        continue;
      }

      // Start from the last statement, or from the first charge if this card
      // has never settled. A card with no charges has nothing to do.
      final since = await _repo.ledger.lastSettlementAt(method.id!) ??
          await _repo.methods.firstChargeAt(method.id!);
      if (since == null) continue;

      final cycles = StatementCycles.closedSince(
        after: since,
        now: now,
        statementDay: statementDay,
      );

      for (final cycle in cycles) {
        final posted = await _repo.settleCycle(method: method, cycle: cycle);
        if (posted) settled++;
      }
    }

    return settled;
  }

  Expense _expenseFrom(RecurringRule rule, DateTime on) {
    final now = DateTime.now();
    return Expense(
      occurredAt: on,
      amountMinor: rule.amountMinor,
      merchant: rule.name,
      description: rule.note,
      categoryId: rule.categoryId,
      paymentMethodId: rule.paymentMethodId,
      recurringRuleId: rule.id,
      receiptPath: '',
      isBusiness: rule.isBusiness,
      createdAt: now,
      updatedAt: now,
    );
  }

  Income _incomeFrom(RecurringRule rule, DateTime on) => Income(
        occurredAt: on,
        amountMinor: rule.amountMinor,
        sourceName: rule.name,
        accountId: rule.accountId,
        note: rule.note,
        recurringRuleId: rule.id,
        createdAt: DateTime.now(),
      );
}
