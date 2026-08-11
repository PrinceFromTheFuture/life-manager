import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shopping_list/apps/receipts/data/expense_repository.dart';
import 'package:shopping_list/apps/receipts/data/location_service.dart';
import 'package:shopping_list/apps/receipts/data/models/account.dart';
import 'package:shopping_list/apps/receipts/data/models/expense.dart';
import 'package:shopping_list/apps/receipts/data/models/expense_category.dart';
import 'package:shopping_list/core/activity/providers.dart';
import 'package:shopping_list/core/providers.dart';

final expenseRepositoryProvider = Provider<ExpenseRepository>(
  (ref) => ExpenseRepository(
    ref.watch(databaseProvider),
    ref.watch(imageStoreProvider),
  ),
);

final locationServiceProvider =
    Provider<LocationService>((ref) => const LocationService());

/// The categories and accounts the form offers as chips. Rarely change, so
/// they're fetched once and reused rather than re-queried per keystroke.
final categoriesProvider = FutureProvider<List<ExpenseCategory>>(
  (ref) => ref.watch(expenseRepositoryProvider).categories(),
);

final accountsProvider = FutureProvider<List<Account>>(
  (ref) => ref.watch(expenseRepositoryProvider).accounts(),
);

/// The expense list.
class ExpensesController extends AsyncNotifier<List<Expense>> {
  @override
  Future<List<Expense>> build() =>
      ref.read(expenseRepositoryProvider).recent();

  ExpenseRepository get _repo => ref.read(expenseRepositoryProvider);

  Future<void> _reload() async {
    state = AsyncData(await _repo.recent());
    // The hub caches these rows, so it is stale the moment this changes.
    ref.invalidate(activityFeedProvider);
  }

  Future<Expense> add({
    required Expense draft,
    required String receiptSourcePath,
  }) async {
    final saved = await _repo.create(
      draft: draft,
      receiptSourcePath: receiptSourcePath,
    );
    await _reload();
    return saved;
  }

  Future<void> edit(Expense expense, {String? receiptSourcePath}) async {
    await _repo.update(expense, receiptSourcePath: receiptSourcePath);
    await _reload();
    ref.invalidate(expenseDetailProvider(expense.id!));
  }

  /// Returns the removed expense so the caller can offer undo.
  Future<void> remove(int id) async {
    await _repo.delete(id);
    await _reload();
  }
}

final expensesProvider =
    AsyncNotifierProvider<ExpensesController, List<Expense>>(
  ExpensesController.new,
);

final expenseDetailProvider =
    FutureProvider.autoDispose.family<Expense?, int>(
  (ref, id) => ref.watch(expenseRepositoryProvider).byId(id),
);

/// Spend so far this calendar month — the one number worth showing above the
/// list, and the reason anyone tracks expenses at all.
final monthToDateProvider = FutureProvider<int>((ref) {
  // Watched so the total refreshes whenever an expense is added or edited.
  ref.watch(expensesProvider);
  final now = DateTime.now();
  final start = DateTime(now.year, now.month);
  final end = DateTime(now.year, now.month + 1);
  return ref.watch(expenseRepositoryProvider).totalBetween(start, end);
});
