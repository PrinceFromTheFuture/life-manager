import 'package:sqflite/sqflite.dart';

import 'package:shopping_list/apps/receipts/data/dao/expense_dao.dart';
import 'package:shopping_list/apps/receipts/data/dao/lookups_dao.dart';
import 'package:shopping_list/apps/receipts/data/models/account.dart';
import 'package:shopping_list/apps/receipts/data/models/expense.dart';
import 'package:shopping_list/apps/receipts/data/models/expense_category.dart';
import 'package:shopping_list/apps/receipts/data/receipts_activity.dart';
import 'package:shopping_list/core/activity/activity_dao.dart';
import 'package:shopping_list/core/activity/activity_entry.dart';
import 'package:shopping_list/core/db/database.dart';
import 'package:shopping_list/core/storage/image_store.dart';

class ExpenseRepository {
  ExpenseRepository(this._appDb, this.images);

  final AppDatabase _appDb;
  final ImageStore images;

  Database get _db => _appDb.db;

  ExpenseDao get expenses => ExpenseDao(_db);
  LookupsDao get lookups => LookupsDao(_db);

  // ---------------------------------------------------------------- reading

  Future<List<Expense>> recent({int limit = 200}) =>
      expenses.recent(limit: limit);

  Future<Expense?> byId(int id) => expenses.byId(id);

  Future<List<ExpenseCategory>> categories() => lookups.categories();
  Future<List<Account>> accounts() => lookups.accounts();

  Future<int?> predictCategory(String merchant) =>
      expenses.predictCategory(merchant);

  Future<List<String>> merchantSuggestions(String query) =>
      expenses.merchantSuggestions(query);

  Future<int> totalBetween(DateTime from, DateTime to) =>
      expenses.totalBetween(from, to);

  // ---------------------------------------------------------------- writing

  /// Creates an expense from a freshly captured receipt.
  ///
  /// The image is copied into managed storage **before** the transaction,
  /// because file I/O cannot participate in a SQLite transaction. If the
  /// insert then fails, the orphaned copy is removed — otherwise a failed save
  /// would silently accumulate unreferenced images.
  Future<Expense> create({
    required Expense draft,
    required String receiptSourcePath,
  }) async {
    final storedPath = await images.saveReceipt(receiptSourcePath);

    try {
      return await _db.transaction((txn) async {
        final expenseDao = ExpenseDao(txn);

        final saved = await expenseDao.insert(
          draft.copyWith(receiptPath: storedPath),
        );

        // Teach the merchant→category association so next time this shop
        // preselects the right chip.
        if (saved.merchant != null && saved.categoryId != null) {
          await expenseDao.learnCategory(saved.merchant!, saved.categoryId!);
        }

        await ActivityWriter(txn).write(
          ActivityEntry(
            appId: ReceiptActivity.appId,
            kind: ReceiptActivity.expenseAdded,
            title: saved.title,
            subtitle: saved.locationLabel,
            amountMinor: saved.amountMinor,
            occurredAt: saved.occurredAt,
            refTable: ReceiptActivity.expensesTable,
            refId: saved.id,
          ),
        );

        return saved;
      });
    } on Exception {
      await images.delete(storedPath);
      rethrow;
    }
  }

  /// Saves edits. [receiptSourcePath] replaces the photo when given.
  Future<void> update(
    Expense expense, {
    String? receiptSourcePath,
  }) async {
    var updated = expense;
    String? previousPath;

    if (receiptSourcePath != null) {
      previousPath = (await expenses.byId(expense.id!))?.receiptPath;
      final stored = await images.saveReceipt(receiptSourcePath);
      updated = updated.copyWith(receiptPath: stored);
    }

    await _db.transaction((txn) async {
      final expenseDao = ExpenseDao(txn);
      await expenseDao.update(updated);

      if (updated.merchant != null && updated.categoryId != null) {
        await expenseDao.learnCategory(updated.merchant!, updated.categoryId!);
      }

      // The feed caches title/subtitle/amount, so an edit has to correct them
      // there too or the hub keeps showing the old values.
      final writer = ActivityWriter(txn);
      await writer.deleteFor(
        appId: ReceiptActivity.appId,
        refTable: ReceiptActivity.expensesTable,
        refId: updated.id!,
      );
      await writer.write(
        ActivityEntry(
          appId: ReceiptActivity.appId,
          kind: ReceiptActivity.expenseAdded,
          title: updated.title,
          subtitle: updated.locationLabel,
          amountMinor: updated.amountMinor,
          occurredAt: updated.occurredAt,
          refTable: ReceiptActivity.expensesTable,
          refId: updated.id,
        ),
      );
    });

    if (previousPath != null && previousPath != updated.receiptPath) {
      await images.delete(previousPath);
    }
  }

  /// Deletes an expense, its feed entry, and its receipt image.
  Future<void> delete(int id) async {
    final expense = await expenses.byId(id);

    await _db.transaction((txn) async {
      await ExpenseDao(txn).delete(id);
      await ActivityWriter(txn).deleteFor(
        appId: ReceiptActivity.appId,
        refTable: ReceiptActivity.expensesTable,
        refId: id,
      );
    });

    if (expense != null) await images.delete(expense.receiptPath);
  }

  Future<ExpenseCategory> addCategory(String name) =>
      lookups.addCategory(name);

  Future<Account> addAccount(String name, {String kind = 'other', String? last4}) =>
      lookups.addAccount(name, kind: kind, last4: last4);
}
