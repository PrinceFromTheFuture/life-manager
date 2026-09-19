import 'package:flutter/material.dart';

import 'package:shopping_list/apps/receipts/data/receipts_activity.dart';
import 'package:shopping_list/apps/receipts/data/receipts_migrations.dart';
import 'package:shopping_list/apps/receipts/ui/expense_detail_screen.dart';
import 'package:shopping_list/apps/receipts/ui/receipts_shell.dart';
import 'package:shopping_list/core/activity/activity_entry.dart';
import 'package:shopping_list/core/activity/activity_row_shell.dart';
import 'package:shopping_list/core/app/mini_app.dart';
import 'package:shopping_list/core/app/mini_app_host.dart';
import 'package:shopping_list/core/db/migration.dart';
import 'package:shopping_list/core/design/widgets/app_icon.dart';

/// Expense tracking, as a mini-app.
class ReceiptsApp implements MiniApp {
  const ReceiptsApp();

  @override
  String get id => ReceiptActivity.appId;

  @override
  String get name => 'Receipts';

  @override
  String get tagline => 'Photograph a receipt. It lands here.';

  /// Iron-gall ledger blue-black — the ink of double-entry bookkeeping, which
  /// oxidises from grey to this on the page. Sober, unmistakably about money,
  /// and clearly distinct from the groceries violet in a mixed feed.
  @override
  AppInk get ink => const AppInk(
        light: Color(0xFF27506E),
        dark: Color(0xFF7FA8D0),
      );

  @override
  SolarIconData get icon => SolarIcons.BillList;

  @override
  ModuleMigrations get migrations => receiptsMigrations;

  @override
  Widget buildHome(BuildContext context) => const ReceiptsShell();

  /// None here — the hub hosts Add expense as its one first-class control,
  /// so capturing a receipt is one tap from home rather than a drawer item.
  @override
  List<QuickAction> quickActions(BuildContext context) => const [];

  @override
  Widget buildActivityRow(BuildContext context, ActivityEntry entry) {
    return ActivityRowShell(
      ink: ink.of(Theme.of(context).brightness),
      title: entry.title,
      subtitle: entry.subtitle,
      amountMinor: entry.amountMinor,
      onTap: entry.refId == null
          ? null
          : () => openMiniApp(
                context,
                this,
                initialScreen: (_) =>
                    ExpenseDetailScreen(expenseId: entry.refId!),
              ),
    );
  }

  @override
  Route<void>? routeForActivity(ActivityEntry entry) {
    if (entry.refTable != ReceiptActivity.expensesTable ||
        entry.refId == null) {
      return null;
    }
    return MaterialPageRoute<void>(
      builder: (_) => ExpenseDetailScreen(expenseId: entry.refId!),
    );
  }
}
