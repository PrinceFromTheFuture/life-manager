import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/apps/receipts/data/models/expense.dart';
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

    test('a week starts on Monday, a month on the first', () {
      // 24 Aug 2026 is a Monday; the 4th is the Tuesday of that earlier week.
      final week = StatsPeriod.containing(
        DateTime(2026, 8, 4),
        StatsGrain.week,
      );
      expect(week.start, DateTime(2026, 8, 3));
      expect(week.dayCount, 7);
      expect(week.lastDay, DateTime(2026, 8, 9));

      final month = StatsPeriod.containing(
        DateTime(2026, 8, 24),
        StatsGrain.month,
      );
      expect(month.start, DateTime(2026, 8));
      expect(month.dayCount, 31);
      expect(
        week.withGrain(StatsGrain.month).start,
        DateTime(2026, 8),
      );
    });

    test('you cannot step a span past the one that holds today', () {
      final now = DateTime(2026, 8, 24, 15);
      final current = StatsPeriod.current(now: now);
      expect(current.start, DateTime(2026, 8, 24));
      expect(current.canAdvance(now: now), isFalse);
      expect(current.previous.canAdvance(now: now), isTrue);
    });

    test('daily stacks split a mixed day by category, busiest ink at the bottom',
        () {
      final period = StatsPeriod.containing(
        DateTime(2026, 8, 4),
        StatsGrain.week,
      );
      final days = ReceiptsView.dailyStacks(
        [
          slip(
            at: DateTime(2026, 8, 4, 10),
            amount: 1000,
            categoryId: 1,
          ),
          slip(
            at: DateTime(2026, 8, 4, 12),
            amount: 4000,
            categoryId: 2,
          ),
          slip(
            at: DateTime(2026, 8, 5),
            amount: 2000,
            categoryId: 1,
          ),
        ],
        period,
      );
      expect(days, hasLength(7));
      expect(days[1].day, DateTime(2026, 8, 4));
      expect(days[1].totalMinor, 5000);
      expect(days[1].slices.map((s) => s.categoryId), [2, 1]);
      expect(days[2].totalMinor, 2000);
      expect(days[0].totalMinor, 0);
    });

    test('category totals rank pads by take, and the series keeps quiet days',
        () {
      final period = StatsPeriod.containing(
        DateTime(2026, 8, 4),
        StatsGrain.week,
      );
      final items = [
        slip(
          at: DateTime(2026, 8, 4),
          amount: 1000,
          categoryId: 1,
        ),
        slip(
          at: DateTime(2026, 8, 4),
          amount: 4000,
          categoryId: 2,
        ),
        slip(
          at: DateTime(2026, 8, 5),
          amount: 2000,
          categoryId: 1,
        ),
      ];
      final totals = ReceiptsView.categoryTotals(items);
      expect(totals.first.categoryId, 2);
      expect(totals.first.amountMinor, 4000);
      expect(totals.last.categoryId, 1);
      expect(totals.last.count, 2);

      final series = ReceiptsView.categorySeries(items, period, 1);
      expect(series, hasLength(7));
      expect(series[1], 1000);
      expect(series[2], 2000);
      expect(series[0], 0);
    });

    test('onDay keeps the slips of one calendar day, oldest first', () {
      final slips = ReceiptsView.onDay(
        [
          slip(id: 1, at: DateTime(2026, 8, 4, 18), amount: 3000),
          slip(id: 2, at: DateTime(2026, 8, 4, 9), amount: 1000),
          slip(id: 3, at: DateTime(2026, 8, 5), amount: 2000),
        ],
        DateTime(2026, 8, 4),
      );
      expect(slips.map((e) => e.id), [2, 1]);
    });
  });
}
