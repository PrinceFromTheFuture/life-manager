import 'package:flutter/material.dart';

import 'package:shopping_list/apps/receipts/data/models/account_entry.dart';
import 'package:shopping_list/apps/receipts/data/receipts_activity.dart';
import 'package:shopping_list/apps/receipts/ui/accounts/income_detail_screen.dart';
import 'package:shopping_list/apps/receipts/ui/expense_detail_screen.dart';

/// Opens the record a ledger line was written from, when there is one.
Future<void> openLedgerReference(
  BuildContext context,
  AccountEntry entry,
) async {
  final id = entry.refId;
  if (id == null) return;
  if (entry.refTable == ReceiptActivity.expensesTable) {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ExpenseDetailScreen(expenseId: id),
      ),
    );
    return;
  }
  if (entry.refTable == ReceiptActivity.incomesTable) {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => IncomeDetailScreen(incomeId: id),
      ),
    );
  }
}

bool ledgerReferenceOpens(AccountEntry entry) =>
    entry.refId != null &&
    (entry.refTable == ReceiptActivity.expensesTable ||
        entry.refTable == ReceiptActivity.incomesTable);
