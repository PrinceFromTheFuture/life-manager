import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:shopping_list/apps/receipts/data/expense_repository.dart';
import 'package:shopping_list/apps/receipts/data/finance/statement_cycle.dart';
import 'package:shopping_list/apps/receipts/data/models/account.dart';
import 'package:shopping_list/apps/receipts/data/models/account_entry.dart';
import 'package:shopping_list/apps/receipts/data/models/expense.dart';
import 'package:shopping_list/apps/receipts/data/models/income.dart';
import 'package:shopping_list/apps/receipts/data/models/payment_method.dart';
import 'package:shopping_list/apps/receipts/data/models/recurring_rule.dart';
import 'package:shopping_list/apps/receipts/data/receipts_migrations.dart';
import 'package:shopping_list/apps/receipts/data/recurring_materializer.dart';
import 'package:shopping_list/core/db/database.dart';
import 'package:shopping_list/core/storage/image_store.dart';

/// The ledger rules, exercised against real SQLite. The maths is covered in
/// finance_test.dart; what matters here is that the right lines get written and
/// that nothing is ever written twice.
void main() {
  late AppDatabase database;
  late ExpenseRepository repo;
  late Directory tempDir;
  late Account account;
  late PaymentMethod direct;
  late PaymentMethod card;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    database = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
      modules: [receiptsMigrations],
    );
    tempDir = await Directory.systemTemp.createTemp('finance_repo_test');
    repo = ExpenseRepository(database, ImageStore(root: tempDir));

    account = await repo.addAccount('Bank Leumi', kind: 'bank');
    await repo.setOpeningBalance(account.id!, 1000000);
    direct = (await repo.paymentMethods()).firstWhere(
      (m) => m.accountId == account.id && m.settlement == Settlement.direct,
    );
    card = await repo.addPaymentMethod(
      PaymentMethod(
        accountId: account.id!,
        name: 'Visa gold',
        settlement: Settlement.indirect,
        statementDay: 10,
        createdAt: DateTime(2026, 1, 1),
      ),
    );
  });

  tearDown(() async {
    await database.close();
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  Future<Expense> spend({
    required int amountMinor,
    required PaymentMethod method,
    DateTime? on,
    String merchant = 'Rami Levy',
  }) {
    final when = on ?? DateTime(2026, 8, 12);
    return repo.createWithoutReceipt(
      Expense(
        occurredAt: when,
        amountMinor: amountMinor,
        merchant: merchant,
        paymentMethodId: method.id,
        receiptPath: '',
        createdAt: when,
        updatedAt: when,
      ),
    );
  }

  Future<int> balance() async {
    final standings = await repo.standings(now: DateTime(2026, 8, 12));
    return standings.firstWhere((s) => s.account.id == account.id).balanceMinor;
  }

  group('posting', () {
    test('a direct payment leaves the account immediately', () async {
      await spend(amountMinor: 28490, method: direct);

      expect(await balance(), 1000000 - 28490);
      final standing = (await repo.standings(now: DateTime(2026, 8, 12)))
          .firstWhere((s) => s.account.id == account.id);
      expect(standing.todayDeltaMinor, -28490);
      final lines = await repo.ledgerFor(account.id!);
      expect(lines.single.entry.kind, LedgerKind.expense);
      expect(lines.single.entry.amountMinor, -28490);
    });

    test('a credit charge does not touch the balance until it settles',
        () async {
      await spend(amountMinor: 50000, method: card);

      expect(await balance(), 1000000);
      expect(await repo.ledgerFor(account.id!), isEmpty);

      final standing = (await repo.standings(now: DateTime(2026, 8, 12)))
          .firstWhere((s) => s.account.id == account.id);
      expect(standing.committed[card.id], 50000);
      expect(standing.owedMinor, 50000);
    });

    test('the account is mirrored from the method it was paid with', () async {
      final saved = await spend(amountMinor: 1000, method: card);
      expect(saved.accountId, account.id);
    });

    test('income arrives in the account it was recorded against', () async {
      await repo.addIncome(
        Income(
          occurredAt: DateTime(2026, 8, 10),
          amountMinor: 2130000,
          sourceName: 'Salary',
          accountId: account.id,
          createdAt: DateTime(2026, 8, 10),
        ),
      );

      expect(await balance(), 1000000 + 2130000);
    });
  });

  group('corrections are appended, never applied in place', () {
    test('editing an amount reverses the old line and posts a new one',
        () async {
      final saved = await spend(amountMinor: 28490, method: direct);
      await repo.update(saved.copyWith(amountMinor: 30000));

      final lines = await repo.ledgerFor(account.id!);
      expect(lines, hasLength(3));
      expect(
        lines.map((l) => l.entry.kind),
        containsAll([LedgerKind.expense, LedgerKind.reversal]),
      );
      expect(await balance(), 1000000 - 30000);
    });

    test('deleting reverses without removing the history', () async {
      final saved = await spend(amountMinor: 28490, method: direct);
      await repo.delete(saved.id!);

      final lines = await repo.ledgerFor(account.id!);
      expect(lines, hasLength(2));
      expect(lines.first.entry.kind, LedgerKind.reversal);
      expect(lines.first.entry.note, contains('Rami Levy'));
      expect(await balance(), 1000000);
    });

    test('a reversal is never itself reversed twice', () async {
      final saved = await spend(amountMinor: 28490, method: direct);
      await repo.update(saved.copyWith(merchant: 'Shufersal'));
      await repo.update(saved.copyWith(merchant: 'Osher Ad'));

      // Two edits: two reversals and three postings, and the balance is still
      // one expense worth of money.
      expect(await balance(), 1000000 - 28490);
    });

    test('deleting an income takes it back out', () async {
      await repo.addIncome(
        Income(
          occurredAt: DateTime(2026, 8, 10),
          amountMinor: 500000,
          sourceName: 'Refund',
          accountId: account.id,
          createdAt: DateTime(2026, 8, 10),
        ),
      );
      final income = (await repo.recentIncomes()).single;
      await repo.deleteIncome(income.id!);

      expect(await balance(), 1000000);
      expect(await repo.recentIncomes(), isEmpty);
    });
  });

  group('settlement', () {
    test('a closed cycle leaves the account in one line', () async {
      await spend(
        amountMinor: 50000,
        method: card,
        on: DateTime(2026, 7, 15),
      );
      await spend(
        amountMinor: 20000,
        method: card,
        on: DateTime(2026, 8, 2),
      );

      final cycle = StatementCycles.containing(DateTime(2026, 7, 15), 10);
      expect(await repo.settleCycle(method: card, cycle: cycle), isTrue);

      final lines = await repo.ledgerFor(account.id!);
      expect(lines.single.entry.kind, LedgerKind.settlement);
      expect(lines.single.entry.amountMinor, -70000);
      expect(lines.single.entry.occurredAt, DateTime(2026, 8, 10));
    });

    test('settling the same cycle twice writes nothing the second time',
        () async {
      await spend(
        amountMinor: 50000,
        method: card,
        on: DateTime(2026, 7, 15),
      );
      final cycle = StatementCycles.containing(DateTime(2026, 7, 15), 10);

      expect(await repo.settleCycle(method: card, cycle: cycle), isTrue);
      expect(await repo.settleCycle(method: card, cycle: cycle), isFalse);
      expect(await repo.ledgerFor(account.id!), hasLength(1));
    });

    test('an empty cycle is not a zero line in the passbook', () async {
      final cycle = StatementCycles.containing(DateTime(2026, 7, 15), 10);
      expect(await repo.settleCycle(method: card, cycle: cycle), isFalse);
      expect(await repo.ledgerFor(account.id!), isEmpty);
    });
  });

  group('the sweep', () {
    Future<RecurringRule> rent({int day = 1}) => repo.addRecurringRule(
          RecurringRule(
            name: 'Rent',
            amountMinor: 320000,
            paymentMethodId: direct.id,
            dayOfMonth: day,
            startsOn: DateTime(2026, 6, 1),
            createdAt: DateTime(2026, 6, 1),
          ),
        );

    test('posts every month a rule was due for, once each', () async {
      await rent();
      final result = await RecurringMaterializer(repo).run(
        now: DateTime(2026, 8, 19),
      );

      expect(result.ordersPosted, 3);
      expect(result.message, '3 standing orders posted.');
      final posted = await repo.recent();
      expect(posted, hasLength(3));
      expect(posted.every((e) => e.isAutoCreated), isTrue);
      expect(posted.every((e) => !e.hasReceipt), isTrue);
    });

    test('a second sweep on the same day writes nothing', () async {
      await rent();
      await RecurringMaterializer(repo).run(now: DateTime(2026, 8, 19));
      final again = await RecurringMaterializer(repo).run(
        now: DateTime(2026, 8, 19),
      );

      expect(again.isEmpty, isTrue);
      expect(again.message, isNull);
      expect(await repo.recent(), hasLength(3));
    });

    test('a paused rule posts nothing', () async {
      final rule = await rent();
      await repo.setRecurringActive(rule.id!, active: false);

      final result = await RecurringMaterializer(repo).run(
        now: DateTime(2026, 8, 19),
      );
      expect(result.ordersPosted, 0);
      expect(await repo.recent(), isEmpty);
    });

    test('an income rule lands as income, not as an expense', () async {
      await repo.addRecurringRule(
        RecurringRule(
          kind: RecurringKind.income,
          name: 'Salary',
          amountMinor: 2130000,
          accountId: account.id,
          dayOfMonth: 10,
          startsOn: DateTime(2026, 8, 1),
          createdAt: DateTime(2026, 8, 1),
        ),
      );

      await RecurringMaterializer(repo).run(now: DateTime(2026, 8, 19));

      expect(await repo.recent(), isEmpty);
      expect((await repo.recentIncomes()).single.sourceName, 'Salary');
      expect(await balance(), 1000000 + 2130000);
    });

    test('closed credit cycles settle as part of the sweep', () async {
      await spend(
        amountMinor: 50000,
        method: card,
        on: DateTime(2026, 6, 15),
      );

      final result = await RecurringMaterializer(repo).run(
        now: DateTime(2026, 8, 19),
      );

      expect(result.statementsSettled, 1);
      expect(result.message, '1 statement settled.');
      expect(await balance(), 1000000 - 50000);

      final again = await RecurringMaterializer(repo).run(
        now: DateTime(2026, 8, 19),
      );
      expect(again.isEmpty, isTrue);
    });
  });
}
