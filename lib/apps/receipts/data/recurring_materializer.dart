import 'package:shopping_list/apps/receipts/data/expense_repository.dart';
import 'package:shopping_list/apps/receipts/data/finance/statement_cycle.dart';

/// What one sweep did, so the app can say so instead of rows appearing from
/// nowhere.
class SweepResult {
  const SweepResult({this.statementsSettled = 0});

  final int statementsSettled;

  bool get isEmpty => statementsSettled == 0;

  /// One line, in the quietest channel the app has. Nothing here earns the
  /// print ceremony — that belongs to a transaction you made yourself.
  String? get message {
    if (isEmpty) return null;
    return statementsSettled == 1
        ? '1 statement settled.'
        : '$statementsSettled statements settled.';
  }
}

/// Writes the credit statements that should already have happened.
///
/// Recurring payments do not post themselves. They are templates: you tap one
/// to log a slip. The sweep's only job now is settling closed card cycles.
class RecurringMaterializer {
  const RecurringMaterializer(this._repo);

  final ExpenseRepository _repo;

  Future<SweepResult> run({DateTime? now}) async {
    final at = now ?? DateTime.now();
    final settled = await _settleClosedCycles(at);
    return SweepResult(statementsSettled: settled);
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
}
