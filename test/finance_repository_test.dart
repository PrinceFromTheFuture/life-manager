import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:shopping_list/core/db/migration.dart';

import 'package:shopping_list/apps/receipts/data/expense_repository.dart';
import 'package:shopping_list/apps/receipts/data/finance/ledger.dart';
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

    test('the open cycle queue lists only that card\'s waiting charges',
        () async {
      await spend(amountMinor: 50000, method: card, on: DateTime(2026, 8, 12));
      await spend(amountMinor: 1000, method: direct, on: DateTime(2026, 8, 12));
      final cycle = StatementCycles.open(DateTime(2026, 8, 12), 10);
      final waiting = await repo.chargedToMethod(
        paymentMethodId: card.id!,
        from: cycle.start,
        to: cycle.end,
      );
      expect(waiting, hasLength(1));
      expect(waiting.single.amountMinor, 50000);
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

    test('a transfer leaves one account and arrives in the other', () async {
      final cash = await repo.addAccount('Cash', kind: 'cash');
      await repo.transfer(
        fromAccountId: account.id!,
        toAccountId: cash.id!,
        amountMinor: 50000,
        occurredAt: DateTime(2026, 8, 12),
      );

      expect(await balance(), 1000000 - 50000);
      final cashBalance =
          (await repo.standings(now: DateTime(2026, 8, 12)))
              .firstWhere((s) => s.account.id == cash.id)
              .balanceMinor;
      expect(cashBalance, 50000);

      final fromLines = await repo.ledgerFor(account.id!);
      final toLines = await repo.ledgerFor(cash.id!);
      expect(fromLines.single.entry.kind, LedgerKind.transfer);
      expect(fromLines.single.entry.amountMinor, -50000);
      expect(fromLines.single.entry.note, 'To Cash');
      expect(toLines.single.entry.kind, LedgerKind.transfer);
      expect(toLines.single.entry.amountMinor, 50000);
      expect(toLines.single.entry.note, 'From Bank Leumi');
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
      await repo.update(saved.copyWith(amountMinor: 30000));
      await repo.update(saved.copyWith(amountMinor: 31000));

      // Two edits: two reversals and three postings, and the balance is still
      // one expense worth of money.
      expect(await balance(), 1000000 - 31000);
      final lines = await repo.ledgerFor(account.id!);
      expect(lines, hasLength(5));
    });

    test('an edit that moves no money leaves the ledger alone', () async {
      final saved = await spend(amountMinor: 28490, method: direct);
      await repo.update(saved.copyWith(merchant: 'Shufersal'));

      // Renaming the shop is not a refund followed by a fresh purchase. Posting
      // a cancelling pair for it was what filled a day with money that never
      // moved.
      final lines = await repo.ledgerFor(account.id!);
      expect(lines, hasLength(1));
      expect(lines.single.entry.kind, LedgerKind.expense);
      expect(lines.single.entry.note, contains('Shufersal'));
      expect(await balance(), 1000000 - 28490);
    });

    test('a correction is dated to the day the money actually moved', () async {
      final saved = await spend(
        amountMinor: 5000,
        method: direct,
        on: DateTime(2026, 8, 3),
      );
      await repo.update(saved.copyWith(amountMinor: 6000));

      final lines = await repo.ledgerFor(account.id!);
      expect(lines, hasLength(3));
      // Every line sits on the 3rd, including the reversal written today, so
      // no other day picks up a phantom credit.
      expect(
        lines.map((l) => l.entry.occurredAt).toSet(),
        {DateTime(2026, 8, 3)},
      );

      // And counted as movement, the day holds one ₪60 slip — not ₪110 out
      // with ₪50 arriving.
      final moved = Ledger.movement(lines);
      expect(moved, hasLength(1));
      expect(moved.single.entry.amountMinor, -6000);
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

    test('a recurring rule never writes a slip on its own', () async {
      await rent();
      final result = await RecurringMaterializer(repo).run(
        now: DateTime(2026, 8, 19),
      );

      expect(result.isEmpty, isTrue);
      expect(result.message, isNull);
      expect(await repo.recent(), isEmpty);
    });

    test('an income rule never lands as income on its own', () async {
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
      expect(await repo.recentIncomes(), isEmpty);
      expect(await balance(), 1000000);
    });

    test('a slip logged from a rule is linked for that calendar month',
        () async {
      final rule = await rent();
      await repo.createWithoutReceipt(
        Expense(
          occurredAt: DateTime(2026, 8, 12),
          amountMinor: 320000,
          merchant: 'Rent',
          categoryId: null,
          paymentMethodId: direct.id,
          recurringRuleId: rule.id,
          receiptPath: '',
          createdAt: DateTime(2026, 8, 12),
          updatedAt: DateTime(2026, 8, 12),
        ),
      );

      expect(
        await repo.recurringLinkedInMonth(now: DateTime(2026, 8, 19)),
        {rule.id},
      );
      expect(
        await repo.recurringLinkedInMonth(now: DateTime(2026, 9, 1)),
        isEmpty,
      );
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

  // Databases already on a phone hold reversals stamped with the day the edit
  // was made. The balance was always right, so nothing but the dates needs
  // repairing — and the dates are what every per-day figure reads.
  group('repairing corrections written before the fix', () {
    test('an existing reversal moves onto the day it cancels', () async {
      final dir = await Directory.systemTemp.createTemp('reversal_backfill');
      final path = p.join(dir.path, 'app.db');

      // The schema as it shipped, without the backfill step.
      final beforeBackfill = ModuleMigrations(
        moduleId: receiptsMigrations.moduleId,
        migrations: receiptsMigrations.migrations
            .where((m) => m.version < 7)
            .toList(),
      );

      final spentOn = DateTime(2026, 8, 3);
      final editedOn = DateTime(2026, 8, 27);

      final old = await AppDatabase.open(
        factory: databaseFactoryFfi,
        path: path,
        modules: [beforeBackfill],
      );
      final acc = await old.db.insert('accounts', {
        'name': 'Bank',
        'kind': 'bank',
        'opening_minor': 0,
        'sort': 0,
        'mark': 'vault',
      });
      final original = await old.db.insert('account_entries', {
        'account_id': acc,
        'occurred_at': spentOn.millisecondsSinceEpoch,
        'amount_minor': -5000,
        'kind': 'expense',
        'created_at': spentOn.millisecondsSinceEpoch,
      });
      // The old behaviour: dated to the correction, not to the movement.
      final reversal = await old.db.insert('account_entries', {
        'account_id': acc,
        'occurred_at': editedOn.millisecondsSinceEpoch,
        'amount_minor': 5000,
        'kind': 'reversal',
        'reverses_id': original,
        'created_at': editedOn.millisecondsSinceEpoch,
      });
      await old.close();

      final repaired = await AppDatabase.open(
        factory: databaseFactoryFfi,
        path: path,
        modules: [receiptsMigrations],
      );
      final rows = await repaired.db.query(
        'account_entries',
        where: 'id = ?',
        whereArgs: [reversal],
      );
      expect(
        rows.single['occurred_at'],
        spentOn.millisecondsSinceEpoch,
        reason: 'the reversal should sit on the day the money moved',
      );
      expect(
        rows.single['created_at'],
        editedOn.millisecondsSinceEpoch,
        reason: 'when the correction was made is still on record',
      );
      await repaired.close();
      await dir.delete(recursive: true);
    });
  });
}
