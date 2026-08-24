import 'package:sqflite/sqflite.dart';

import 'package:shopping_list/apps/receipts/data/dao/expense_dao.dart';
import 'package:shopping_list/apps/receipts/data/dao/income_dao.dart';
import 'package:shopping_list/apps/receipts/data/dao/ledger_dao.dart';
import 'package:shopping_list/apps/receipts/data/dao/lookups_dao.dart';
import 'package:shopping_list/apps/receipts/data/dao/payment_method_dao.dart';
import 'package:shopping_list/apps/receipts/data/dao/recurring_dao.dart';
import 'package:shopping_list/apps/receipts/data/finance/calendar.dart';
import 'package:shopping_list/apps/receipts/data/finance/ledger.dart';
import 'package:shopping_list/apps/receipts/data/finance/statement_cycle.dart';
import 'package:shopping_list/apps/receipts/data/dao/account_view_dao.dart';
import 'package:shopping_list/apps/receipts/data/models/account.dart';
import 'package:shopping_list/apps/receipts/data/models/account_view.dart';
import 'package:shopping_list/apps/receipts/data/models/account_entry.dart';
import 'package:shopping_list/apps/receipts/data/models/expense.dart';
import 'package:shopping_list/apps/receipts/data/models/expense_category.dart';
import 'package:shopping_list/apps/receipts/data/models/income.dart';
import 'package:shopping_list/apps/receipts/data/models/month_kind_totals.dart';
import 'package:shopping_list/apps/receipts/data/models/payment_method.dart';
import 'package:shopping_list/apps/receipts/data/models/recurring_rule.dart';
import 'package:shopping_list/apps/receipts/data/receipts_activity.dart';
import 'package:shopping_list/core/activity/activity_dao.dart';
import 'package:shopping_list/core/activity/activity_entry.dart';
import 'package:shopping_list/core/db/database.dart';
import 'package:shopping_list/core/storage/image_store.dart';

/// An account's balance and what is owed on the cards hanging off it.
class AccountStanding {
  const AccountStanding({
    required this.account,
    required this.methods,
    required this.balanceMinor,
    required this.committed,
    this.todayDeltaMinor = 0,
  });

  final Account account;
  final List<PaymentMethod> methods;

  /// Opening balance plus every ledger entry. Money that is actually there.
  final int balanceMinor;

  /// Charged to each credit method in its open cycle and not yet settled,
  /// keyed by method id. Not part of [balanceMinor] — it has not left yet.
  final Map<int, int> committed;

  /// What moved today. Positive arrived, negative left.
  final int todayDeltaMinor;

  int get owedMinor => committed.values.fold(0, (sum, value) => sum + value);
}

/// Standings that belong on the page right now.
///
/// All (a null view) keeps the old rule: the headline is live accounts, the
/// carousel still shows retired ones so their history is reachable. A named
/// view is only the accounts that were picked, in the order the passbooks
/// already use.
List<AccountStanding> standingsInView(
  List<AccountStanding> standings,
  AccountView? view, {
  required bool forHeadline,
}) {
  if (view == null) {
    if (!forHeadline) return standings;
    return [
      for (final s in standings)
        if (s.account.archivedAt == null) s,
    ];
  }
  final ids = view.accountIds.toSet();
  return [
    for (final s in standings)
      if (ids.contains(s.account.id)) s,
  ];
}

class ExpenseRepository {
  ExpenseRepository(this._appDb, this.images);

  final AppDatabase _appDb;
  final ImageStore images;

  Database get _db => _appDb.db;

  ExpenseDao get expenses => ExpenseDao(_db);
  LookupsDao get lookups => LookupsDao(_db);
  PaymentMethodDao get methods => PaymentMethodDao(_db);
  LedgerDao get ledger => LedgerDao(_db);
  IncomeDao get incomes => IncomeDao(_db);
  RecurringDao get recurring => RecurringDao(_db);
  AccountViewDao get views => AccountViewDao(_db);

  // ---------------------------------------------------------------- reading

  Future<List<Expense>> recent({int limit = 200}) =>
      expenses.recent(limit: limit);

  Future<List<Expense>> between(DateTime from, DateTime to) =>
      expenses.between(from, to);

  Future<Expense?> byId(int id) => expenses.byId(id);

  Future<Income?> incomeById(int id) => incomes.byId(id);

  Future<List<ExpenseCategory>> categories() => lookups.categories();
  Future<List<Account>> accounts() => lookups.accounts();

  Future<int?> predictCategory(String merchant) =>
      expenses.predictCategory(merchant);

  Future<List<String>> merchantSuggestions(String query) =>
      expenses.merchantSuggestions(query);

  Future<int> totalBetween(DateTime from, DateTime to) =>
      expenses.totalBetween(from, to);

  Future<List<MonthKindTotals>> kindTotalsByMonth({int months = 12}) =>
      expenses.kindTotalsByMonth(months: months);

  // -------------------------------------------------------- payment methods

  Future<List<PaymentMethod>> paymentMethods() => methods.all();

  Future<PaymentMethod?> paymentMethodById(int id) => methods.byId(id);

  /// Methods in the order the expense sheet should offer them: busiest first,
  /// so the correction you actually make is the leftmost alternative.
  Future<List<PaymentMethod>> paymentMethodsByUse() async {
    final all = await methods.all();
    final ranked = await methods.idsByUse();
    final position = {
      for (var i = 0; i < ranked.length; i++) ranked[i]: i,
    };

    final sorted = [...all]..sort((a, b) {
        final left = position[a.id] ?? 1 << 30;
        final right = position[b.id] ?? 1 << 30;
        if (left != right) return left.compareTo(right);
        return a.sort.compareTo(b.sort);
      });
    return sorted;
  }

  Future<int?> lastUsedPaymentMethodId() => methods.lastUsedId();

  Future<PaymentMethod> addPaymentMethod(PaymentMethod method) =>
      methods.insert(method);

  Future<void> updatePaymentMethod(PaymentMethod method) =>
      methods.update(method);

  Future<void> archivePaymentMethod(int id) => methods.archive(id);

  Future<int> paymentMethodUsage(int id) => methods.usage(id);

  // ----------------------------------------------------------------- ledger

  /// Every account with its derived balance and what its cards owe.
  ///
  /// Assembled in one pass rather than per account: the sums and the method
  /// list are each a single query, and the accounts screen needs all of them
  /// before it can draw anything.
  Future<List<AccountStanding>> standings({DateTime? now}) async {
    final at = now ?? DateTime.now();
    // Retired accounts are included, and sorted to the bottom. They are gone
    // from every picker, but their ledger has to stay reachable — a balance
    // you can no longer open is a balance you have to take on faith.
    final everyAccount = await lookups.accounts(includeArchived: true);
    final all = [
      ...everyAccount.where((a) => a.archivedAt == null),
      ...everyAccount.where((a) => a.archivedAt != null),
    ];
    final allMethods = await methods.all();
    final sums = await ledger.sums();
    final todaySums = await ledger.sumsSince(Calendar.startOfDay(at));

    final byAccount = <int, List<PaymentMethod>>{};
    for (final method in allMethods) {
      byAccount.putIfAbsent(method.accountId, () => []).add(method);
    }

    final standings = <AccountStanding>[];
    for (final account in all) {
      final id = account.id!;
      final mine = byAccount[id] ?? const <PaymentMethod>[];

      final committed = <int, int>{};
      for (final method in mine) {
        if (!method.isCredit || method.statementDay == null) continue;
        final cycle = StatementCycles.open(at, method.statementDay!);
        committed[method.id!] = await methods.chargedBetween(
          method.id!,
          cycle.start,
          cycle.end,
        );
      }

      standings.add(
        AccountStanding(
          account: account,
          methods: mine,
          balanceMinor: account.openingMinor + (sums[id] ?? 0),
          committed: committed,
          todayDeltaMinor: todaySums[id] ?? 0,
        ),
      );
    }

    return standings;
  }

  Future<List<LedgerLine>> ledgerFor(int accountId) async {
    final account = await lookups.accountById(accountId);
    final entries = await ledger.entriesFor(accountId);
    return Ledger.lines(
      openingMinor: account?.openingMinor ?? 0,
      entries: entries,
    );
  }

  Future<void> setOpeningBalance(int accountId, int openingMinor) async {
    final account = await lookups.accountById(accountId);
    if (account == null) return;
    await _db.update(
      'accounts',
      account.copyWith(openingMinor: openingMinor).toMap(),
      where: 'id = ?',
      whereArgs: [accountId],
    );
  }

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
      return await _db.transaction(
        (txn) => _insert(txn, draft.copyWith(receiptPath: storedPath)),
      );
    } on Exception {
      await images.delete(storedPath);
      rethrow;
    }
  }

  /// Creates an expense nobody photographed — a standing order posting itself.
  ///
  /// Stores an empty `receipt_path`, which every surface that shows a photo
  /// already knows how to read as "there isn't one".
  Future<Expense> createWithoutReceipt(Expense draft) =>
      _db.transaction((txn) => _insert(txn, draft.copyWith(receiptPath: '')));

  Future<Expense> _insert(DatabaseExecutor txn, Expense draft) async {
    final expenseDao = ExpenseDao(txn);
    final mirrored = await _mirrorAccount(txn, draft);
    final saved = await expenseDao.insert(mirrored);

    // Teach the merchant→category association so next time this shop
    // preselects the right chip.
    if (saved.merchant != null && saved.categoryId != null) {
      await expenseDao.learnCategory(saved.merchant!, saved.categoryId!);
    }

    await _postExpense(txn, saved);

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
      updated = await _mirrorAccount(txn, updated);
      await expenseDao.update(updated);

      if (updated.merchant != null && updated.categoryId != null) {
        await expenseDao.learnCategory(updated.merchant!, updated.categoryId!);
      }

      // The ledger is append-only, so a correction is two lines: one undoing
      // what the old version posted, one posting what the new version does.
      await _reverseEntriesFor(txn, updated.id!);
      await _postExpense(txn, updated);

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
  ///
  /// The ledger keeps its lines: what left the account really did leave, and a
  /// reversal says so explicitly rather than the history quietly changing
  /// shape.
  Future<void> delete(int id) async {
    final expense = await expenses.byId(id);

    await _db.transaction((txn) async {
      await _reverseEntriesFor(txn, id);
      await ExpenseDao(txn).delete(id);
      await ActivityWriter(txn).deleteFor(
        appId: ReceiptActivity.appId,
        refTable: ReceiptActivity.expensesTable,
        refId: id,
      );
    });

    if (expense != null && expense.hasReceipt) {
      await images.delete(expense.receiptPath);
    }
  }

  /// Fills in which account a slip drained, from the method it was paid with.
  Future<Expense> _mirrorAccount(DatabaseExecutor txn, Expense expense) async {
    final methodId = expense.paymentMethodId;
    if (methodId == null) return expense;
    final method = await PaymentMethodDao(txn).byId(methodId);
    if (method == null) return expense;
    return expense.copyWith(accountId: method.accountId);
  }

  /// Posts a direct payment to the ledger.
  ///
  /// A credit charge deliberately posts nothing. The ledger records money
  /// leaving the account, and a card charge has not done that yet — it will,
  /// in one lump, when the statement settles.
  Future<void> _postExpense(DatabaseExecutor txn, Expense expense) async {
    final methodId = expense.paymentMethodId;
    if (methodId == null) return;

    final method = await PaymentMethodDao(txn).byId(methodId);
    if (method == null || method.isCredit) return;

    final now = DateTime.now();
    await LedgerDao(txn).append(
      AccountEntry(
        accountId: method.accountId,
        occurredAt: expense.occurredAt,
        amountMinor: -expense.amountMinor,
        kind: LedgerKind.expense,
        refTable: ReceiptActivity.expensesTable,
        refId: expense.id,
        note: expense.title,
        createdAt: now,
      ),
    );
  }

  Future<void> _reverseEntriesFor(DatabaseExecutor txn, int expenseId) async {
    final dao = LedgerDao(txn);
    final live = await dao.liveEntriesFor(
      refTable: ReceiptActivity.expensesTable,
      refId: expenseId,
    );
    for (final entry in live) {
      await dao.append(Ledger.reversalOf(entry));
    }
  }

  // ---------------------------------------------------------------- incomes

  Future<List<Income>> recentIncomes({int limit = 60}) =>
      incomes.recent(limit: limit);

  Future<List<String>> incomeSourceSuggestions(String query) =>
      incomes.sourceSuggestions(query);

  Future<Income> addIncome(Income draft) async {
    return _db.transaction((txn) async {
      final saved = await IncomeDao(txn).insert(draft);

      if (saved.accountId != null) {
        await LedgerDao(txn).append(
          AccountEntry(
            accountId: saved.accountId!,
            occurredAt: saved.occurredAt,
            amountMinor: saved.amountMinor,
            kind: LedgerKind.income,
            refTable: ReceiptActivity.incomesTable,
            refId: saved.id,
            note: saved.sourceName,
            createdAt: DateTime.now(),
          ),
        );
      }

      await ActivityWriter(txn).write(
        ActivityEntry(
          appId: ReceiptActivity.appId,
          kind: ReceiptActivity.incomeAdded,
          title: saved.sourceName,
          subtitle: 'Income',
          amountMinor: saved.amountMinor,
          occurredAt: saved.occurredAt,
          refTable: ReceiptActivity.incomesTable,
          refId: saved.id,
        ),
      );

      return saved;
    });
  }

  Future<void> deleteIncome(int id) async {
    await _db.transaction((txn) async {
      final dao = LedgerDao(txn);
      final live = await dao.liveEntriesFor(
        refTable: ReceiptActivity.incomesTable,
        refId: id,
      );
      for (final entry in live) {
        await dao.append(Ledger.reversalOf(entry));
      }
      await IncomeDao(txn).delete(id);
      await ActivityWriter(txn).deleteFor(
        appId: ReceiptActivity.appId,
        refTable: ReceiptActivity.incomesTable,
        refId: id,
      );
    });
  }

  // -------------------------------------------------------- standing orders

  Future<List<RecurringRule>> recurringRules() => recurring.all();

  Future<RecurringRule> addRecurringRule(RecurringRule rule) =>
      recurring.insert(rule);

  Future<void> updateRecurringRule(RecurringRule rule) =>
      recurring.update(rule);

  Future<void> setRecurringActive(int id, {required bool active}) =>
      recurring.setActive(id, active: active);

  Future<void> deleteRecurringRule(int id) => recurring.delete(id);

  Future<int> recurringMonthlyTotal() => recurring.monthlyTotal();

  /// Posts one credit statement to the account it draws on.
  ///
  /// Returns whether anything was written: a cycle that has already settled, or
  /// one with nothing charged to it, is a no-op rather than an empty line in
  /// the passbook.
  Future<bool> settleCycle({
    required PaymentMethod method,
    required StatementCycle cycle,
  }) async {
    return _db.transaction((txn) async {
      final dao = LedgerDao(txn);
      final already = await dao.hasSettlement(
        paymentMethodId: method.id!,
        settlesOn: cycle.settlesOn,
      );
      if (already) return false;

      final charged = await PaymentMethodDao(txn).chargedBetween(
        method.id!,
        cycle.start,
        cycle.end,
      );
      if (charged == 0) return false;

      await dao.append(
        AccountEntry(
          accountId: method.accountId,
          occurredAt: cycle.settlesOn,
          amountMinor: -charged,
          kind: LedgerKind.settlement,
          refTable: ReceiptActivity.paymentMethodsTable,
          refId: method.id,
          note: 'Statement · ${method.label}',
          createdAt: DateTime.now(),
        ),
      );
      return true;
    });
  }

  // ---------------------------------------------------------------- lookups

  Future<ExpenseCategory> addCategory(String name, {String? ink}) =>
      lookups.addCategory(name, ink: ink);

  Future<void> renameCategory(int id, String name) =>
      lookups.renameCategory(id, name);

  Future<void> setCategoryInk(int id, String ink) =>
      lookups.setCategoryInk(id, ink);

  Future<int> categoryUsage(int id) => lookups.categoryUsage(id);

  Future<void> deleteCategory(int id) => lookups.deleteCategory(id);

  Future<void> reorderCategories(List<int> idsInOrder) =>
      lookups.reorderCategories(idsInOrder);

  /// Adds an account together with the one direct method every account needs
  /// to be usable — an account you cannot pay from is a dead end, and making
  /// people create two records to spend cash would be absurd.
  Future<Account> addAccount(
    String name, {
    String kind = 'other',
    String? last4,
    String? mark,
  }) async {
    final created = await lookups.addAccount(
      name,
      kind: kind,
      last4: last4,
      mark: mark,
    );
    final existing = await methods.forAccount(created.id!);
    if (existing.isEmpty) {
      await methods.insert(
        PaymentMethod(
          accountId: created.id!,
          name: created.name,
          last4: last4,
          createdAt: DateTime.now(),
        ),
      );
    }
    return created;
  }

  Future<void> renameAccount(int id, String name) =>
      lookups.renameAccount(id, name);

  Future<void> setAccountMark(int id, String mark) =>
      lookups.setAccountMark(id, mark);

  Future<int> accountUsage(int id) => lookups.accountUsage(id);

  Future<void> deleteAccount(int id) => lookups.deleteAccount(id);

  Future<void> archiveAccount(int id) => lookups.archiveAccount(id);

  Future<void> reorderAccounts(List<int> idsInOrder) =>
      lookups.reorderAccounts(idsInOrder);

  Future<List<AccountView>> accountViews() => views.all();

  Future<int?> activeAccountViewId() => views.activeId();

  Future<void> setActiveAccountView(int? id) => views.setActive(id);

  Future<AccountView> saveAccountView(AccountView view) => views.save(view);

  Future<void> deleteAccountView(int id) => views.delete(id);
}
