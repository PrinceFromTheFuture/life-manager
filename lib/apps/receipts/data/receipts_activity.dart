/// Identifiers the receipts app writes into the shared feed.
abstract final class ReceiptActivity {
  /// Must match `ReceiptsApp.id`; persisted in `activity.app_id`.
  static const String appId = 'receipts';

  static const String expenseAdded = 'expense_added';

  static const String expensesTable = 'expenses';
}
