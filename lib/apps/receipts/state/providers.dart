import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shopping_list/apps/receipts/data/expense_repository.dart';
import 'package:shopping_list/apps/receipts/data/location_service.dart';
import 'package:shopping_list/apps/receipts/data/models/account.dart';
import 'package:shopping_list/apps/receipts/data/models/expense.dart';
import 'package:shopping_list/apps/receipts/data/models/expense_category.dart';
import 'package:shopping_list/apps/receipts/data/models/month_kind_totals.dart';
import 'package:shopping_list/apps/receipts/data/ocr/ocr_source.dart';
import 'package:shopping_list/apps/receipts/data/ocr/receipt_parser.dart';
import 'package:shopping_list/apps/receipts/data/ocr/receipt_scanner.dart';
import 'package:shopping_list/core/activity/providers.dart';
import 'package:shopping_list/core/providers.dart';
import 'package:shopping_list/core/settings/api_keys.dart';

final expenseRepositoryProvider = Provider<ExpenseRepository>(
  (ref) => ExpenseRepository(
    ref.watch(databaseProvider),
    ref.watch(imageStoreProvider),
  ),
);

final locationServiceProvider =
    Provider<LocationService>((ref) => const LocationService());

/// The scanner, built fresh from whatever keys are currently stored. Null
/// when either key is missing — the form falls back to manual entry rather
/// than offering a scan that can only fail.
///
/// Not autoDispose: a scan in flight would otherwise be cancelled the moment
/// the choice stage rebuilt, which is exactly when the request is running.
final receiptScannerProvider = FutureProvider<ReceiptScanner?>(
  (ref) async {
    final store = ref.watch(apiKeyStoreProvider);
    final visionKey = await store.read(ApiKeyKind.googleVision);
    final openRouterKey = await store.read(ApiKeyKind.openRouter);
    if (visionKey == null || openRouterKey == null) return null;

    return ReceiptScanner(
      ocr: GoogleVisionOcr(visionKey),
      parser: ReceiptParser(openRouterKey),
      model: 'deepseek/deepseek-v4-flash',
    );
  },
);

/// The categories and accounts the form offers as chips. Rarely change, so
/// they're fetched once and reused rather than re-queried per keystroke.
final categoriesProvider = FutureProvider<List<ExpenseCategory>>(
  (ref) => ref.watch(expenseRepositoryProvider).categories(),
);

final accountsProvider = FutureProvider<List<Account>>(
  (ref) => ref.watch(expenseRepositoryProvider).accounts(),
);

/// Refreshes both lookup lists after they're managed from settings. Kept
/// separate from [ExpensesController] — editing a category list has nothing to
/// do with the expenses themselves.
class LookupsController {
  LookupsController(this.ref);

  final Ref ref;

  ExpenseRepository get _repo => ref.read(expenseRepositoryProvider);

  Future<void> _reload() async {
    ref.invalidate(categoriesProvider);
    ref.invalidate(accountsProvider);
  }

  Future<ExpenseCategory> addCategory(String name) async {
    final created = await _repo.addCategory(name);
    await _reload();
    return created;
  }

  Future<void> renameCategory(int id, String name) async {
    await _repo.renameCategory(id, name);
    await _reload();
  }

  Future<int> categoryUsage(int id) => _repo.categoryUsage(id);

  Future<void> deleteCategory(int id) async {
    await _repo.deleteCategory(id);
    await _reload();
  }

  Future<void> reorderCategories(List<int> idsInOrder) async {
    await _repo.reorderCategories(idsInOrder);
    await _reload();
  }

  Future<Account> addAccount(String name) async {
    final created = await _repo.addAccount(name);
    await _reload();
    return created;
  }

  Future<void> renameAccount(int id, String name) async {
    await _repo.renameAccount(id, name);
    await _reload();
  }

  Future<int> accountUsage(int id) => _repo.accountUsage(id);

  Future<void> deleteAccount(int id) async {
    await _repo.deleteAccount(id);
    await _reload();
  }

  Future<void> reorderAccounts(List<int> idsInOrder) async {
    await _repo.reorderAccounts(idsInOrder);
    await _reload();
  }
}

final lookupsControllerProvider =
    Provider<LookupsController>((ref) => LookupsController(ref));

/// The expense list.
class ExpensesController extends AsyncNotifier<List<Expense>> {
  @override
  Future<List<Expense>> build() => ref.read(expenseRepositoryProvider).recent();

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
    // Land on the month you just wrote, even if you had stepped the list
    // back to look at an older one before adding.
    final when = saved.occurredAt;
    ref.read(selectedMonthProvider.notifier).state =
        DateTime(when.year, when.month);
    await _reload();
    return saved;
  }

  Future<void> edit(Expense expense, {String? receiptSourcePath}) async {
    await _repo.update(expense, receiptSourcePath: receiptSourcePath);
    await _reload();
    ref.invalidate(expenseDetailProvider(expense.id!));
  }

  Future<void> remove(int id) async {
    await _repo.delete(id);
    await _reload();
    ref.invalidate(expenseDetailProvider(id));
  }
}

final expensesProvider =
    AsyncNotifierProvider<ExpensesController, List<Expense>>(
  ExpensesController.new,
);

final expenseDetailProvider = FutureProvider.autoDispose.family<Expense?, int>(
  (ref, id) => ref.watch(expenseRepositoryProvider).byId(id),
);

// ------------------------------------------------------------- month scoping

/// The month shown on the receipts list and in statistics. Always the first
/// of the month at midnight, so it can double as a range start.
final selectedMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
});

DateTime _monthAfter(DateTime month) => DateTime(month.year, month.month + 1);

/// Every expense in the selected month. A real database query rather than a
/// client-side filter of [expensesProvider]'s capped result — a month several
/// pages back must not silently come up empty because it fell outside that
/// cap.
final monthExpensesProvider = FutureProvider.autoDispose<List<Expense>>((ref) {
  // Recompute whenever the ledger changes underneath it.
  ref.watch(expensesProvider);
  final month = ref.watch(selectedMonthProvider);
  return ref
      .watch(expenseRepositoryProvider)
      .between(month, _monthAfter(month));
});

/// The hero number above the list and atop statistics.
final selectedMonthTotalProvider = FutureProvider.autoDispose<int>((ref) {
  ref.watch(expensesProvider);
  final month = ref.watch(selectedMonthProvider);
  return ref
      .watch(expenseRepositoryProvider)
      .totalBetween(month, _monthAfter(month));
});

/// What the month before the selected one cost, so statistics can say whether
/// this month is up or down rather than showing a number with nothing to
/// compare it to.
final previousMonthTotalProvider = FutureProvider.autoDispose<int>((ref) {
  ref.watch(expensesProvider);
  final month = ref.watch(selectedMonthProvider);
  final previous = DateTime(month.year, month.month - 1);
  return ref.watch(expenseRepositoryProvider).totalBetween(previous, month);
});

/// Business vs personal, month by month, so statistics can show what was
/// claimed without opening every slip.
final kindTotalsByMonthProvider =
    FutureProvider.autoDispose<List<MonthKindTotals>>((ref) {
  ref.watch(expensesProvider);
  return ref.watch(expenseRepositoryProvider).kindTotalsByMonth();
});
