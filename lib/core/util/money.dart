/// Money is stored, passed around, and compared as an integer count of agorot.
///
/// It never becomes a `double` at any point, including during parsing — the
/// text input is split on the decimal point and each side is parsed as an
/// integer. `double.parse('142.50') * 100` yields 14249.999999999998 on some
/// inputs, and rounding that away is exactly the bug this class exists to
/// prevent.
abstract final class Money {
  static const String currencyCode = 'ILS';
  static const String symbol = '₪';

  /// Formats agorot for display: `14250` -> `₪142.50`.
  static String format(int agorot) {
    final negative = agorot < 0;
    final abs = agorot.abs();
    final whole = _group((abs ~/ 100).toString());
    final frac = (abs % 100).toString().padLeft(2, '0');
    return '${negative ? '-' : ''}$symbol$whole.$frac';
  }

  /// Formats without the symbol, for use next to an explicit currency label.
  static String formatBare(int agorot) {
    final abs = agorot.abs();
    return '${agorot < 0 ? '-' : ''}'
        '${_group((abs ~/ 100).toString())}.'
        '${(abs % 100).toString().padLeft(2, '0')}';
  }

  /// Parses user input into agorot, or returns null if it isn't a valid
  /// amount. Accepts `142`, `142.5`, `142.50`, `1,420.50`, `₪142.50`.
  ///
  /// Deliberately rejects more than two decimal places rather than truncating:
  /// silently dropping a digit from someone's grocery total is worse than
  /// making them retype it.
  static int? tryParse(String raw) {
    var s = raw.trim().replaceAll(symbol, '');
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
    // Guard against absurd input overflowing the integer maths.
    if (wholeText.length > 12) return null;

    final whole = int.tryParse(wholeText);
    if (whole == null) return null;

    final frac = fracText.isEmpty ? 0 : int.parse(fracText.padRight(2, '0'));

    final total = whole * 100 + frac;
    return negative ? -total : total;
  }

  /// Inserts thousands separators into a digit string.
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
