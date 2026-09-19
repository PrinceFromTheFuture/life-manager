import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/core/util/load.dart';

void main() {
  group('Load.tryParse', () {
    test('parses whole kilograms', () {
      expect(Load.tryParse('80'), 80000);
      expect(Load.tryParse('0'), 0);
    });

    test('parses plate increments exactly', () {
      expect(Load.tryParse('62.5'), 62500);
      expect(Load.tryParse('2.5'), 2500);
      expect(Load.tryParse('1.25'), 1250);
      expect(Load.tryParse('0.25'), 250);
    });

    test('tolerates the unit, spaces and thousands separators', () {
      expect(Load.tryParse('80 kg'), 80000);
      expect(Load.tryParse('  62.5  '), 62500);
      expect(Load.tryParse('1,250'), 1250000);
    });

    test('rejects rather than truncating extra decimal places', () {
      expect(Load.tryParse('62.505'), isNull);
    });

    test('rejects nonsense', () {
      expect(Load.tryParse(''), isNull);
      expect(Load.tryParse('abc'), isNull);
      expect(Load.tryParse('1.2.3'), isNull);
    });

    test('never loses a value to floating point', () {
      for (var grams = 0; grams <= 200000; grams += 250) {
        final text = Load.formatBare(grams);
        expect(Load.tryParse(text), grams, reason: 'round trip of $text');
      }
    });
  });

  group('Load.format', () {
    test('drops trailing zeros', () {
      expect(Load.format(80000), '80 kg');
      expect(Load.format(62500), '62.5 kg');
      expect(Load.format(1250), '1.25 kg');
    });

    test('zero is bodyweight, not a missing value', () {
      expect(Load.format(0), 'bodyweight');
    });

    test('groups thousands on volume', () {
      expect(Load.formatVolume(2560000), '2,560 kg');
      expect(Load.formatVolume(0), '0 kg');
    });
  });
}

