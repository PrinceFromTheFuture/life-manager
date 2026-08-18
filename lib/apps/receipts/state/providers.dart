import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shopping_list/apps/receipts/data/expense_repository.dart';
import 'package:shopping_list/apps/receipts/data/finance/ledger.dart';
import 'package:shopping_list/apps/receipts/data/location_service.dart';
import 'package:shopping_list/apps/receipts/data/models/account.dart';
import 'package:shopping_list/apps/receipts/data/models/expense.dart';
import 'package:shopping_list/apps/receipts/data/models/expense_category.dart';
import 'package:shopping_list/apps/receipts/data/models/income.dart';
import 'package:shopping_list/apps/receipts/data/models/month_kind_totals.dart';
import 'package:shopping_list/apps/receipts/data/models/payment_method.dart';
import 'package:shopping_list/apps/receipts/data/models/recurring_rule.dart';
import 'package:shopping_list/apps/receipts/data/receipts_view.dart';
import 'package:shopping_list/apps/receipts/data/recurring_materializer.dart';
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

  /// Public because the standing-order sweep writes expenses behind the list's
  /// back and has to tell it so.
  Future<void> reload() async {
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
    await reload();
    return saved;
  }

  Future<void> edit(Expense expense, {String? receiptSourcePath}) async {
    await _repo.update(expense, receiptSourcePath: receiptSourcePath);
    await reload();
    ref.invalidate(expenseDetailProvider(expense.id!));
  }

  Future<void> remove(int id) async {
    await _repo.delete(id);
    await reload();
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

/// Last month through the same calendar day — the fair comparison while
/// this month is still open.
final lastMonthToDateProvider = FutureProvider.autoDispose<int>((ref) {
  ref.watch(expensesProvider);
  final month = ref.watch(selectedMonthProvider);
  final now = DateTime.now();
  final previous = DateTime(month.year, month.month - 1);
  final isCurrent = now.year == month.year && now.month == month.month;
  final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
  final day = isCurrent ? now.day.clamp(1, daysInMonth) : daysInMonth;
  final daysInPrev = DateTime(previous.year, previous.month + 1, 0).day;
  final clip = day.clamp(1, daysInPrev);
  final to = DateTime(previous.year, previous.month, clip + 1);
  return ref.watch(expenseRepositoryProvider).totalBetween(previous, to);
});

// --------------------------------------------------------------- navigation

/// Which divider tab the shell is showing. A provider rather than widget state
/// so the section survives pushing a detail screen and coming back.
final receiptsTabProvider = StateProvider<int>((ref) => 0);

// ------------------------------------------------------------------ finance

/// Bumped by every write that touches the ledger from outside the expense list
/// — income, a settlement, a new payment method, a standing order.
///
/// One dial rather than a list of invalidations at each call site: forgetting
/// one of five `ref.invalidate` lines is how a balance ends up stale on one
/// screen and correct on the next.
final financeRevisionProvider = StateProvider<int>((ref) => 0);

final paymentMethodsProvider = FutureProvider<List<PaymentMethod>>((ref) {
  ref.watch(financeRevisionProvider);
  return ref.watch(expenseRepositoryProvider).paymentMethods();
});

/// The order the expense sheet offers them in: busiest first.
final paymentMethodsByUseProvider =
    FutureProvider<List<PaymentMethod>>((ref) {
  ref.watch(financeRevisionProvider);
  ref.watch(expensesProvider);
  return ref.watch(expenseRepositoryProvider).paymentMethodsByUse();
});

/// What the sheet preselects, so the common capture needs no tap here at all.
final lastUsedPaymentMethodProvider = FutureProvider<int?>((ref) {
  ref.watch(expensesProvider);
  return ref.watch(expenseRepositoryProvider).lastUsedPaymentMethodId();
});

final accountStandingsProvider =
    FutureProvider.autoDispose<List<AccountStanding>>((ref) {
  ref.watch(expensesProvider);
  ref.watch(financeRevisionProvider);
  return ref.watch(expenseRepositoryProvider).standings();
});

final accountLedgerProvider =
    FutureProvider.autoDispose.family<List<LedgerLine>, int>((ref, accountId) {
  ref.watch(expensesProvider);
  ref.watch(financeRevisionProvider);
  return ref.watch(expenseRepositoryProvider).ledgerFor(accountId);
});

final recentIncomesProvider = FutureProvider.autoDispose<List<Income>>((ref) {
  ref.watch(financeRevisionProvider);
  return ref.watch(expenseRepositoryProvider).recentIncomes();
});

final recurringRulesProvider = FutureProvider<List<RecurringRule>>((ref) {
  ref.watch(financeRevisionProvider);
  return ref.watch(expenseRepositoryProvider).recurringRules();
});

final recurringMonthlyTotalProvider = FutureProvider<int>((ref) {
  ref.watch(financeRevisionProvider);
  return ref.watch(expenseRepositoryProvider).recurringMonthlyTotal();
});

/// Everything that writes money outside the expense list.
///
/// Each method bumps [financeRevisionProvider] once, at the end, so a screen
/// rebuilds exactly once per action rather than once per affected query.
class FinanceController {
  FinanceController(this.ref);

  final Ref ref;

  ExpenseRepository get _repo => ref.read(expenseRepositoryProvider);

  void _touch() =>
      ref.read(financeRevisionProvider.notifier).state++;

  Future<Account> addAccount(String name, {String kind = 'other'}) async {
    final created = await _repo.addAccount(name, kind: kind);
    ref.invalidate(accountsProvider);
    _touch();
    return created;
  }

  Future<void> setOpeningBalance(int accountId, int openingMinor) async {
    await _repo.setOpeningBalance(accountId, openingMinor);
    ref.invalidate(accountsProvider);
    _touch();
  }

  Future<void> archiveAccount(int id) async {
    await _repo.archiveAccount(id);
    ref.invalidate(accountsProvider);
    _touch();
  }

  Future<void> addPaymentMethod(PaymentMethod method) async {
    await _repo.addPaymentMethod(method);
    _touch();
  }

  Future<void> updatePaymentMethod(PaymentMethod method) async {
    await _repo.updatePaymentMethod(method);
    _touch();
  }

  Future<void> archivePaymentMethod(int id) async {
    await _repo.archivePaymentMethod(id);
    _touch();
  }

  Future<void> addIncome(Income income) async {
    await _repo.addIncome(income);
    ref.invalidate(activityFeedProvider);
    _touch();
  }

  Future<void> deleteIncome(int id) async {
    await _repo.deleteIncome(id);
    ref.invalidate(activityFeedProvider);
    _touch();
  }

  Future<void> addRule(RecurringRule rule) async {
    await _repo.addRecurringRule(rule);
    _touch();
  }

  Future<void> updateRule(RecurringRule rule) async {
    await _repo.updateRecurringRule(rule);
    _touch();
  }

  Future<void> setRuleActive(int id, {required bool active}) async {
    await _repo.setRecurringActive(id, active: active);
    _touch();
  }

  Future<void> deleteRule(int id) async {
    await _repo.deleteRecurringRule(id);
    _touch();
  }

  /// Posts what should already have happened. Returns null when there was
  /// nothing to do, which is the overwhelmingly common case.
  Future<SweepResult> sweep() async {
    final result = await RecurringMaterializer(_repo).run();
    if (!result.isEmpty) {
      await ref.read(expensesProvider.notifier).reload();
      _touch();
    }
    return result;
  }
}

final financeControllerProvider =
    Provider<FinanceController>((ref) => FinanceController(ref));

final receiptsLensProvider =
    StateProvider<ReceiptsLens>((ref) => ReceiptsLens.all);

final receiptsSortProvider =
    StateProvider<ReceiptsSort>((ref) => ReceiptsSort.newest);

/// Business vs personal, month by month, so statistics can show what was
/// claimed without opening every slip.
final kindTotalsByMonthProvider =
    FutureProvider.autoDispose<List<MonthKindTotals>>((ref) {
  ref.watch(expensesProvider);
  return ref.watch(expenseRepositoryProvider).kindTotalsByMonth();
});
