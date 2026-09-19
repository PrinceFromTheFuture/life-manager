import 'package:flutter_test/flutter_test.dart';

import 'package:shopping_list/apps/receipts/data/finance/calendar.dart';
import 'package:shopping_list/apps/receipts/data/finance/installment_plan.dart';
import 'package:shopping_list/apps/receipts/data/finance/ledger.dart';
import 'package:shopping_list/apps/receipts/data/finance/recurrence.dart';
import 'package:shopping_list/apps/receipts/data/finance/statement_cycle.dart';
import 'package:shopping_list/apps/receipts/data/models/account_entry.dart';
import 'package:shopping_list/apps/receipts/data/models/recurring_rule.dart';
import 'package:shopping_list/apps/receipts/ui/accounts/change_chip.dart';

RecurringRule _rule({
  required int day,
  required DateTime startsOn,
  DateTime? endsOn,
  DateTime? lastRunOn,
  bool active = true,
}) =>
    RecurringRule(
      id: 1,
      name: 'Rent',
      amountMinor: 320000,
      dayOfMonth: day,
      startsOn: startsOn,
      endsOn: endsOn,
      lastRunOn: lastRunOn,
      active: active,
      createdAt: startsOn,
    );

AccountEntry _entry(int amount, {int day = 1, LedgerKind? kind}) => AccountEntry(
      id: day,
      accountId: 1,
      occurredAt: DateTime(2026, 8, day),
      amountMinor: amount,
      kind: kind ?? LedgerKind.expense,
      createdAt: DateTime(2026, 8, day),
    );

void main() {
  group('Calendar', () {
    test('clamps a day past the end of a short month', () {
      expect(Calendar.dayOf(2026, 2, 31), DateTime(2026, 2, 28));
      expect(Calendar.dayOf(2024, 2, 31), DateTime(2024, 2, 29));
      expect(Calendar.dayOf(2026, 4, 31), DateTime(2026, 4, 30));
    });

    test('keeps a day that fits', () {
      expect(Calendar.dayOf(2026, 8, 10), DateTime(2026, 8, 10));
    });

    test('normalises month overflow into the next year', () {
      expect(Calendar.dayOf(2026, 13, 10), DateTime(2027, 1, 10));
      expect(Calendar.dayOf(2026, 0, 10), DateTime(2025, 12, 10));
    });
  });

  group('StatementCycles', () {
    test('a charge before the statement day belongs to the open cycle', () {
      final cycle = StatementCycles.containing(DateTime(2026, 8, 3), 10);
      expect(cycle.start, DateTime(2026, 7, 10));
      expect(cycle.end, DateTime(2026, 8, 10));
    });

    test('a charge on the statement day starts the new cycle', () {
      final cycle = StatementCycles.containing(DateTime(2026, 8, 10), 10);
      expect(cycle.start, DateTime(2026, 8, 10));
      expect(cycle.settlesOn, DateTime(2026, 9, 10));
    });

    test('a cycle spanning the year boundary is contiguous', () {
      final december = StatementCycles.containing(DateTime(2026, 12, 20), 15);
      expect(december.start, DateTime(2026, 12, 15));
      expect(december.end, DateTime(2027, 1, 15));
    });

    test('the 31st settles on the last day of a short month', () {
      final cycle = StatementCycles.containing(DateTime(2026, 2, 10), 31);
      expect(cycle.start, DateTime(2026, 1, 31));
      expect(cycle.end, DateTime(2026, 2, 28));
    });

    test('closedSince lists every finished cycle, oldest first', () {
      final cycles = StatementCycles.closedSince(
        after: DateTime(2026, 5, 10),
        now: DateTime(2026, 8, 12),
        statementDay: 10,
      );
      expect(
        cycles.map((c) => c.end).toList(),
        [
          DateTime(2026, 6, 10),
          DateTime(2026, 7, 10),
          DateTime(2026, 8, 10),
        ],
      );
    });

    test('closedSince excludes the cycle that ended exactly at the cutoff', () {
      final cycles = StatementCycles.closedSince(
        after: DateTime(2026, 8, 10),
        now: DateTime(2026, 8, 12),
        statementDay: 10,
      );
      expect(cycles, isEmpty);
    });

    test('the still-open cycle is never listed as closed', () {
      final cycles = StatementCycles.closedSince(
        after: DateTime(2026, 7, 10),
        now: DateTime(2026, 8, 9),
        statementDay: 10,
      );
      expect(cycles, isEmpty);
    });
  });

  group('InstallmentPlan', () {
    test('one payment is the whole charge', () {
      final plan = InstallmentPlan.split(principalMinor: 119900, count: 1);
      expect(plan.payments, [119900]);
      expect(plan.caption, '1 payment');
    });

    test('an interest-free split adds up to the principal exactly', () {
      final plan = InstallmentPlan.split(principalMinor: 31300, count: 3);
      expect(plan.payments, [10434, 10433, 10433]);
      expect(plan.totalMinor, 31300);
      expect(plan.interestMinor, 0);
      expect(plan.caption, '3 payments · ₪104.34, then ₪104.33 x2');
    });

    test('an even split says "each" rather than naming a remainder', () {
      final plan = InstallmentPlan.split(principalMinor: 120000, count: 4);
      expect(plan.payments, [30000, 30000, 30000, 30000]);
      expect(plan.caption, '4 payments · ₪300.00 each');
    });

    test('every interest-free split of any size is exact', () {
      for (var count = 1; count <= 36; count++) {
        for (final principal in [1, 99, 100, 31300, 999999, 1234567]) {
          final plan = InstallmentPlan.split(
            principalMinor: principal,
            count: count,
          );
          expect(
            plan.totalMinor,
            principal,
            reason: '$principal over $count payments',
          );
          expect(plan.payments.length, count);
        }
      }
    });

    test('interest amortizes monthly from an annual nominal rate', () {
      final plan = InstallmentPlan.split(
        principalMinor: 120000,
        count: 12,
        interestBp: 600,
      );
      expect(plan.payments.first, 10328);
      expect(plan.isEven, isTrue);
      expect(plan.interestMinor, greaterThan(0));
      expect(plan.caption, '12 payments · ₪103.28 each · 6% a year');
    });

    test('a single payment ignores any rate that was left set', () {
      final plan = InstallmentPlan.split(
        principalMinor: 50000,
        count: 1,
        interestBp: 900,
      );
      expect(plan.totalMinor, 50000);
      expect(plan.caption, '1 payment');
    });

    test('rate formatting drops trailing zeros', () {
      expect(InstallmentPlan.formatRate(600), '6%');
      expect(InstallmentPlan.formatRate(650), '6.5%');
      expect(InstallmentPlan.formatRate(1225), '12.25%');
    });
  });

  group('Ledger', () {
    test('balance is opening plus every entry', () {
      final balance = Ledger.balance(
        openingMinor: 100000,
        entries: [_entry(-25000), _entry(-1000, day: 2)],
      );
      expect(balance, 74000);
    });

    test('lines carry a running balance and read newest first', () {
      final lines = Ledger.lines(
        openingMinor: 100000,
        entries: [
          _entry(-25000),
          _entry(50000, day: 2, kind: LedgerKind.income),
          _entry(-5000, day: 3),
        ],
      );
      expect(lines.map((l) => l.balanceAfter).toList(), [120000, 125000, 75000]);
      expect(lines.first.entry.amountMinor, -5000);
    });

    test('a reversal cancels the entry it points at', () {
      final original = _entry(-25000);
      final reversal = Ledger.reversalOf(original, when: DateTime(2026, 8, 5));

      expect(reversal.amountMinor, 25000);
      expect(reversal.kind, LedgerKind.reversal);
      expect(reversal.reversesId, original.id);
      expect(
        Ledger.balance(openingMinor: 0, entries: [original, reversal]),
        0,
      );
    });

    test('a reversal is dated to the line it cancels, not to the correction',
        () {
      final original = _entry(-25000, day: 3);
      final reversal = Ledger.reversalOf(original, when: DateTime(2026, 8, 20));

      // The money left on the 3rd, so undoing it belongs on the 3rd. Dating it
      // to the 20th invented a credit on a day nothing happened.
      expect(reversal.occurredAt, DateTime(2026, 8, 3));
      expect(reversal.createdAt, DateTime(2026, 8, 20));
    });

    test('movement leaves out a corrected line and its correction', () {
      // A ₪50 slip, corrected to ₪60: three lines, one real movement.
      final spentOn = DateTime(2026, 8, 3);
      final original = AccountEntry(
        id: 1,
        accountId: 1,
        occurredAt: spentOn,
        amountMinor: -5000,
        kind: LedgerKind.expense,
        createdAt: spentOn,
      );
      final reversal = AccountEntry(
        id: 2,
        accountId: 1,
        occurredAt: spentOn,
        amountMinor: 5000,
        kind: LedgerKind.reversal,
        reversesId: 1,
        createdAt: DateTime(2026, 8, 9),
      );
      final replacement = AccountEntry(
        id: 3,
        accountId: 1,
        occurredAt: spentOn,
        amountMinor: -6000,
        kind: LedgerKind.expense,
        createdAt: DateTime(2026, 8, 9),
      );

      final lines = Ledger.lines(
        openingMinor: 100000,
        entries: [original, reversal, replacement],
      );

      final moved = Ledger.movement(lines);
      expect(moved, hasLength(1));
      expect(moved.single.entry.amountMinor, -6000);

      // Counted gross, the raw lines read as ₪110 out and ₪50 in.
      var out = 0;
      var arrived = 0;
      for (final line in lines) {
        if (line.entry.amountMinor < 0) out += -line.entry.amountMinor;
        if (line.entry.amountMinor > 0) arrived += line.entry.amountMinor;
      }
      expect(out, 11000);
      expect(arrived, 5000);
    });

    test('movement keeps every line when nothing was corrected', () {
      final lines = Ledger.lines(
        openingMinor: 0,
        entries: [
          _entry(-2500, day: 1),
          _entry(50000, day: 2, kind: LedgerKind.income),
          _entry(-1000, day: 3),
        ],
      );
      expect(Ledger.movement(lines), hasLength(3));
    });
  });

  group('Recurrence', () {
    test('a new rule is due for every month since it started', () {
      final due = Recurrence.datesDue(
        _rule(day: 10, startsOn: DateTime(2026, 6, 1)),
        now: DateTime(2026, 8, 19),
      );
      expect(due, [
        DateTime(2026, 6, 10),
        DateTime(2026, 7, 10),
        DateTime(2026, 8, 10),
      ]);
    });

    test('nothing is due twice once it has run', () {
      final rule = _rule(
        day: 10,
        startsOn: DateTime(2026, 6, 1),
        lastRunOn: DateTime(2026, 8, 10),
      );
      expect(Recurrence.datesDue(rule, now: DateTime(2026, 8, 19)), isEmpty);
    });

    test('a day past the month end runs on the last day of February', () {
      final due = Recurrence.datesDue(
        _rule(day: 31, startsOn: DateTime(2026, 1, 1)),
        now: DateTime(2026, 3, 5),
      );
      expect(due, [
        DateTime(2026, 1, 31),
        DateTime(2026, 2, 28),
      ]);
    });

    test('a day later this month is not due yet', () {
      final due = Recurrence.datesDue(
        _rule(day: 25, startsOn: DateTime(2026, 8, 1)),
        now: DateTime(2026, 8, 19),
      );
      expect(due, isEmpty);
    });

    test('a paused rule is never due', () {
      final due = Recurrence.datesDue(
        _rule(day: 1, startsOn: DateTime(2026, 1, 1), active: false),
        now: DateTime(2026, 8, 19),
      );
      expect(due, isEmpty);
    });

    test('an ended rule stops at its end date', () {
      final due = Recurrence.datesDue(
        _rule(
          day: 10,
          startsOn: DateTime(2026, 6, 1),
          endsOn: DateTime(2026, 7, 15),
        ),
        now: DateTime(2026, 8, 19),
      );
      expect(due, [DateTime(2026, 6, 10), DateTime(2026, 7, 10)]);
    });

    test('nextRun points at this month while the day is still ahead', () {
      final next = Recurrence.nextRun(
        _rule(day: 25, startsOn: DateTime(2026, 1, 1)),
        now: DateTime(2026, 8, 19),
      );
      expect(next, DateTime(2026, 8, 25));
    });

    test('nextRun rolls to next month once the day has passed', () {
      final next = Recurrence.nextRun(
        _rule(day: 10, startsOn: DateTime(2026, 1, 1)),
        now: DateTime(2026, 8, 19),
      );
      expect(next, DateTime(2026, 9, 10));
    });

    test('nextRun on a rule that has not started yet uses its start date', () {
      final next = Recurrence.nextRun(
        _rule(day: 5, startsOn: DateTime(2026, 11, 1)),
        now: DateTime(2026, 8, 19),
      );
      expect(next, DateTime(2026, 11, 5));
    });
  });

  group('today\'s move as a share of midnight', () {
    test('a 0.2 percent dip formats to one decimal', () {
      expect(ChangeChip.percentLabel(-4210, 2100000), '0.2%');
    });

    test('a midnight of zero has no percentage', () {
      expect(ChangeChip.percentLabel(2500, 2500), isNull);
    });

    test('no move reads as zero, not as an empty chip', () {
      expect(ChangeChip.percentLabel(0, 1800000), '0%');
    });
  });
}
