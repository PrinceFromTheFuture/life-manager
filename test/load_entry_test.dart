import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list/apps/gym/ui/load_keypad.dart';

void main() {
  group('LoadEntry.replaceOnType', () {
    test('a digit replaces the prefilled load instead of appending', () {
      final entry = LoadEntry.fromGrams(80000).pendingReplace;
      expect(entry.press('7').raw, '7');
    });

    test('further digits then append', () {
      final started = LoadEntry.fromGrams(80000).pendingReplace.press('7');
      expect(started.replaceOnType, isFalse);
      expect(started.press('5').raw, '75');
    });

    test('a dot starts a new decimal rather than hanging off the old value', () {
      expect(
        LoadEntry.fromGrams(80000).pendingReplace.dot().raw,
        '0.',
      );
    });

    test('backspace clears the selection rather than nicking one digit', () {
      expect(LoadEntry.fromGrams(62500).pendingReplace.backspace().raw, '');
    });

    test('nudging keeps the value selected so the next digit still replaces',
        () {
      final nudged = LoadEntry.fromGrams(80000).pendingReplace.addGrams(2500);
      expect(nudged.grams, 82500);
      expect(nudged.replaceOnType, isTrue);
      expect(nudged.press('9').raw, '9');
    });
  });

  group('RepsEntry.replaceOnType', () {
    test('a digit replaces last-set reps instead of making 18 from 8', () {
      expect(RepsEntry.fromValue(8).pendingReplace.press('1').raw, '1');
    });

    test('further digits then append', () {
      final started = RepsEntry.fromValue(8).pendingReplace.press('1');
      expect(started.press('2').raw, '12');
    });
  });
}
