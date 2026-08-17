/// Weight on the bar, stored as an integer count of grams.
///
/// It never becomes a `double` at any point, including during parsing — the
/// text input is split on the decimal point and each side is parsed as an
/// integer. The same rule as money: `double.parse('62.5') * 1000` is how a
/// 2.5 kg plate quietly becomes 62.499999 kg, and rounding that away is
/// exactly the bug this class exists to prevent.
///
/// Display unit is kilograms. Two decimal places is the limit (10 g), which
/// covers 1.25 kg plates without inviting milligram noise.
abstract final class Load {
  static const String unit = 'kg';

  /// Grams in one kilogram.
  static const int gramsPerKg = 1000;

  /// Formats grams for display: `80000` -> `80 kg`, `62500` -> `62.5 kg`.
  /// Zero is bodyweight, not a missing value.
  static String format(int grams) {
    if (grams == 0) return 'bodyweight';
    return '${formatBare(grams)} $unit';
  }

  /// Kilograms without the unit, for the keypad and for lining up a column.
  static String formatBare(int grams) {
    final negative = grams < 0;
    final abs = grams.abs();
    final whole = _group((abs ~/ gramsPerKg).toString());
    final frac = abs % gramsPerKg;
    final sign = negative ? '-' : '';
    if (frac == 0) return '$sign$whole';
    if (frac % 100 == 0) return '$sign$whole.${frac ~/ 100}';
    if (frac % 10 == 0) {
      return '$sign$whole.${(frac ~/ 10).toString().padLeft(2, '0')}';
    }
    return '$sign$whole.${frac.toString().padLeft(3, '0')}';
  }

  /// Volume — grams × reps — shown as kilograms moved.
  static String formatVolume(int gramReps) {
    if (gramReps == 0) return '0 $unit';
    return '${formatBare(gramReps)} $unit';
  }

  /// Parses user input into grams, or returns null if it isn't a valid load.
  /// Accepts `80`, `62.5`, `1.25`, `80 kg`, `1,250`.
  ///
  /// Rejects more than two decimal places rather than truncating: silently
  /// dropping a digit from a working weight is worse than making them retype.
  static int? tryParse(String raw) {
    var s = raw.trim().toLowerCase();
    s = s.replaceAll(unit, '');
    s = s.replaceAll(RegExp(r'[\s ,]'), '');
    if (s.isEmpty) return null;

    var negative = false;
    if (s.startsWith('-')) {
      negative = true;
      s = s.substring(1);
    }

    if (!RegExp(r'^\d*\.?\d*$').hasMatch(s)) return null;

    final parts = s.split('.');
    if (parts.length > 2) return null;

    final wholeText = parts[0].isEmpty ? '0' : parts[0];
    final fracText = parts.length == 2 ? parts[1] : '';
    if (fracText.length > 2) return null;
    if (wholeText.isEmpty && fracText.isEmpty) return null;
    if (wholeText.length > 6) return null;

    final whole = int.tryParse(wholeText);
    if (whole == null) return null;

    final frac = fracText.isEmpty ? 0 : int.parse(fracText.padRight(2, '0'));

    final total = whole * gramsPerKg + frac * 10;
    return negative ? -total : total;
  }

  static String _group(String digits) {
    if (digits.length <= 3) return digits;
    final buffer = StringBuffer();
    final firstGroup = digits.length % 3;
    var i = 0;
    if (firstGroup > 0) {
      buffer.write(digits.substring(0, firstGroup));
      i = firstGroup;
    }
    while (i < digits.length) {
      if (buffer.isNotEmpty) buffer.write(',');
      buffer.write(digits.substring(i, i + 3));
      i += 3;
    }
    return buffer.toString();
  }
}
