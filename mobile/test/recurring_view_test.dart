import 'package:flutter_test/flutter_test.dart';

import 'package:shopping_list/apps/receipts/data/models/recurring_rule.dart';
import 'package:shopping_list/apps/receipts/data/recurring_view.dart';

void main() {
  RecurringRule rule({
    required int id,
    required String name,
    required int amount,
    int day = 1,
    int? categoryId,
    RecurringKind kind = RecurringKind.expense,
  }) {
    return RecurringRule(
      id: id,
      kind: kind,
      name: name,
      amountMinor: amount,
      categoryId: categoryId,
      dayOfMonth: day,
      startsOn: DateTime(2026, 1, 1),
      createdAt: DateTime(2026, 1, 1),
    );
  }

  group('RecurringView.grouped', () {
    test('groups by category, sorted by total, rows by due day', () {
      final groups = RecurringView.grouped(
        [
          rule(id: 1, name: 'Gym', amount: 200, day: 20, categoryId: 2),
          rule(id: 2, name: 'Rent', amount: 3000, day: 1, categoryId: 1),
          rule(id: 3, name: 'Netflix', amount: 50, day: 5, categoryId: 2),
          rule(
            id: 4,
            name: 'Salary',
            amount: 8000,
            day: 10,
            kind: RecurringKind.income,
          ),
        ],
        categoryNames: {1: 'Home', 2: 'Leisure'},
      );

      expect(groups.map((g) => g.name), ['Home', 'Leisure', 'Coming in']);
      expect(groups[0].rules.map((r) => r.name), ['Rent']);
      expect(groups[1].rules.map((r) => r.name), ['Netflix', 'Gym']);
    });

    test('unfiled expenses sit together', () {
      final groups = RecurringView.grouped(
        [rule(id: 1, name: 'Mystery', amount: 10, day: 3)],
        categoryNames: const {},
      );
      expect(groups.single.name, 'Unfiled');
    });
  });

  group('RecurringView.dayStacks', () {
    test('a due day carries its category, an empty day is a blank well', () {
      final stacks = RecurringView.dayStacks([
        rule(id: 1, name: 'Rent', amount: 3000, day: 1, categoryId: 1),
        rule(id: 2, name: 'Gym', amount: 200, day: 1, categoryId: 2),
      ]);
      expect(stacks, hasLength(31));
      expect(stacks[0].map((s) => s.categoryId), [1, 2]);
      expect(stacks[14], isEmpty);
    });
  });
}
