import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/util/money.dart';
import 'package:shopping_list/util/normalize.dart';

void main() {
  group('Money.tryParse', () {
    test('parses whole amounts', () {
      expect(Money.tryParse('142'), 14200);
      expect(Money.tryParse('0'), 0);
    });

    test('parses decimals exactly', () {
      expect(Money.tryParse('142.50'), 14250);
      expect(Money.tryParse('142.5'), 14250);
      expect(Money.tryParse('0.01'), 1);
      expect(Money.tryParse('.99'), 99);
    });

    test('tolerates symbols, spaces and thousands separators', () {
      expect(Money.tryParse('₪142.50'), 14250);
      expect(Money.tryParse('  142.50  '), 14250);
      expect(Money.tryParse('1,420.50'), 142050);
    });

    test('rejects rather than truncating extra decimal places', () {
      // Silently dropping a digit from someone's total is worse than making
      // them retype it.
      expect(Money.tryParse('142.505'), isNull);
    });

    test('rejects nonsense', () {
      expect(Money.tryParse(''), isNull);
      expect(Money.tryParse('abc'), isNull);
      expect(Money.tryParse('1.2.3'), isNull);
      expect(Money.tryParse('12e5'), isNull);
    });

    test('never loses a value to floating point', () {
      // double.parse('X.YZ') * 100 drifts on many of these; integer parsing
      // does not. This is the bug the whole class exists to prevent.
      for (var agorot = 0; agorot < 20000; agorot += 7) {
        final text = Money.formatBare(agorot);
        expect(Money.tryParse(text), agorot, reason: 'round trip of $text');
      }
    });
  });

  group('Money.format', () {
    test('always shows two decimal places', () {
      expect(Money.format(14250), '₪142.50');
      expect(Money.format(14200), '₪142.00');
      expect(Money.format(5), '₪0.05');
      expect(Money.format(0), '₪0.00');
    });

    test('groups thousands', () {
      expect(Money.format(142050), '₪1,420.50');
      expect(Money.format(123456789), '₪1,234,567.89');
    });

    test('handles negatives', () {
      expect(Money.format(-14250), '-₪142.50');
    });
  });

  group('normalizeName', () {
    test('collapses case and whitespace', () {
      expect(normalizeName('  Milk '), 'milk');
      expect(normalizeName('OAT   MILK'), 'oat milk');
      expect(normalizeName('Milk'), normalizeName('milk'));
    });

    test('strips Hebrew niqqud so pointed and unpointed match', () {
      expect(normalizeName('חָלָב'), normalizeName('חלב'));
    });
  });

  group('escapeLike', () {
    test('escapes wildcards so they search literally', () {
      expect(escapeLike('50%'), r'50\%');
      expect(escapeLike('a_b'), r'a\_b');
    });
  });
}
