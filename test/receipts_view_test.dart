import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/apps/receipts/data/models/expense.dart';
import 'package:shopping_list/apps/receipts/data/models/month_kind_totals.dart';
import 'package:shopping_list/apps/receipts/data/receipts_view.dart';

void main() {
  Expense slip({
    required DateTime at,
    required int amount,
    int? id,
    String? merchant,
    int? categoryId,
    bool business = false,
  }) {
    return Expense(
      id: id,
      occurredAt: at,
      amountMinor: amount,
      merchant: merchant,
      categoryId: categoryId,
      receiptPath: 'receipts/x.jpg',
      isBusiness: business,
      createdAt: at,
      updatedAt: at,
    );
  }

  group('lenses', () {
    final items = [
      slip(
        id: 1,
        at: DateTime(2026, 8, 2),
        amount: 4000,
        merchant: 'Cafe',
        business: true,
      ),
      slip(
        id: 2,
        at: DateTime(2026, 8, 3),
        amount: 12000,
        merchant: 'Rami Levy',
        categoryId: 1,
      ),
      slip(
        id: 3,
        at: DateTime(2026, 8, 4),
        amount: 8000,
        merchant: 'Office Depot',
        categoryId: 2,
        business: true,
      ),
      slip(
        id: 4,
        at: DateTime(2026, 8, 5),
        amount: 2000,
        merchant: 'Kiosk',
      ),
    ];

    test('to claim keeps only business slips', () {
      final shown = ReceiptsView.apply(
        items,
        lens: ReceiptsLens.toClaim,
        sort: ReceiptsSort.newest,
      );
      expect(shown.map((e) => e.merchant), ['Office Depot', 'Cafe']);
    });

    test('unfiled keeps slips with no category', () {
      final shown = ReceiptsView.apply(
        items,
        lens: ReceiptsLens.unfiled,
        sort: ReceiptsSort.newest,
      );
      expect(shown.map((e) => e.merchant), ['Kiosk', 'Cafe']);
    });

    test('large slips are the upper quartile', () {
      expect(ReceiptsView.largeCutoff(items), 12000);
      final shown = ReceiptsView.apply(
        items,
        lens: ReceiptsLens.large,
        sort: ReceiptsSort.newest,
      );
      expect(shown.single.merchant, 'Rami Levy');
    });

    test('large slips need four amounts before they mean anything', () {
      expect(ReceiptsView.largeCutoff(items.take(3).toList()), isNull);
    });
  });

  group('sorts', () {
    final items = [
      slip(
        id: 1,
        at: DateTime(2026, 8, 10, 9),
        amount: 5000,
        merchant: 'Zeta',
      ),
      slip(
        id: 2,
        at: DateTime(2026, 8, 11, 9),
        amount: 9000,
        merchant: 'Alpha',
      ),
      slip(
        id: 3,
        at: DateTime(2026, 8, 12, 9),
        amount: 3000,
        merchant: 'Beta',
      ),
    ];

    test('newest is the default time order', () {
      final shown = ReceiptsView.apply(
        items,
        lens: ReceiptsLens.all,
        sort: ReceiptsSort.newest,
      );
      expect(shown.map((e) => e.id), [3, 2, 1]);
    });

    test('largest puts the biggest slip first', () {
      final shown = ReceiptsView.apply(
        items,
        lens: ReceiptsLens.all,
        sort: ReceiptsSort.largest,
      );
      expect(shown.map((e) => e.amountMinor), [9000, 5000, 3000]);
    });

    test('merchant is alphabetical, then newest', () {
      final shown = ReceiptsView.apply(
        items,
        lens: ReceiptsLens.all,
        sort: ReceiptsSort.merchant,
      );
      expect(shown.map((e) => e.merchant), ['Alpha', 'Beta', 'Zeta']);
    });
  });

  group('charts', () {
    test('the merchant tape ranks shops by take, with a visit count', () {
      final tape = ReceiptsView.merchantTape([
        slip(
          at: DateTime(2026, 8, 1),
          amount: 3000,
          merchant: 'Cafe',
        ),
        slip(
          at: DateTime(2026, 8, 2),
          amount: 4000,
          merchant: 'Cafe',
        ),
        slip(
          at: DateTime(2026, 8, 3),
          amount: 10000,
          merchant: 'Rami Levy',
        ),
      ]);
      expect(tape.first.name, 'Rami Levy');
      expect(tape.last.name, 'Cafe');
      expect(tape.last.count, 2);
      expect(tape.last.amountMinor, 7000);
    });

    test('statement weeks bucket a month the way a statement does', () {
      final weeks = ReceiptsView.statementWeeks(
        [
          slip(at: DateTime(2026, 8, 3), amount: 1000),
          slip(
            at: DateTime(2026, 8, 10),
            amount: 2000,
            business: true,
          ),
          slip(at: DateTime(2026, 8, 30), amount: 4000),
        ],
        DateTime(2026, 8),
      );
      expect(weeks, hasLength(5));
      expect(weeks[0].amountMinor, 1000);
      expect(weeks[1].businessMinor, 2000);
      expect(weeks[4].fromDay, 29);
      expect(weeks[4].toDay, 31);
      expect(weeks[4].amountMinor, 4000);
    });

    test('daily kind splits a mixed day', () {
      final days = ReceiptsView.dailyKind(
        [
          slip(
            at: DateTime(2026, 8, 4),
            amount: 1000,
            business: true,
          ),
          slip(at: DateTime(2026, 8, 4), amount: 3000),
        ],
        DateTime(2026, 8),
      );
      expect(days[3].day, 4);
      expect(days[3].businessMinor, 1000);
      expect(days[3].personalMinor, 3000);
    });

    test('the register keeps blank months so a gap still prints', () {
      final filled = ReceiptsView.registerMonths(
        [
          MonthKindTotals(
            month: DateTime(2026, 8),
            businessMinor: 100,
            personalMinor: 50,
          ),
        ],
        now: DateTime(2026, 8, 18),
        months: 3,
      );
      expect(filled, hasLength(3));
      expect(filled[0].month, DateTime(2026, 6));
      expect(filled[0].totalMinor, 0);
      expect(filled[2].businessMinor, 100);
    });

    test('pace projects the open month from spend to date', () {
      final pace = ReceiptsView.pace(
        month: DateTime(2026, 8),
        thisMonth: [
          slip(at: DateTime(2026, 8, 5), amount: 10000),
          slip(at: DateTime(2026, 8, 20), amount: 5000),
        ],
        lastMonthToDate: 8000,
        now: DateTime(2026, 8, 10),
      );
      expect(pace.day, 10);
      expect(pace.daysInMonth, 31);
      expect(pace.spentToDate, 10000);
      expect(pace.projected, 31000);
      expect(pace.deltaToDate, 2000);
      expect(pace.monthComplete, isFalse);
    });

    test('Friday and Saturday count as the weekend', () {
      // 14 Aug 2026 is a Friday, 16 Aug is a Sunday.
      final spend = ReceiptsView.weekendSpend([
        slip(at: DateTime(2026, 8, 14), amount: 1000),
        slip(at: DateTime(2026, 8, 15), amount: 2000),
        slip(at: DateTime(2026, 8, 16), amount: 4000),
      ]);
      expect(spend, 3000);
    });
  });
}
