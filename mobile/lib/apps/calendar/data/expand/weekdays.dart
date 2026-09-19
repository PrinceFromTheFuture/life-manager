/// Sunday-first weekday mask used by weekly series.
///
/// Bit 0 is Sunday, bit 6 is Saturday. That matches [Days.startOfWeek] and
/// `DateTime.weekday % 7`.
abstract final class Weekdays {
  static const int sunday = 1 << 0;
  static const int monday = 1 << 1;
  static const int tuesday = 1 << 2;
  static const int wednesday = 1 << 3;
  static const int thursday = 1 << 4;
  static const int friday = 1 << 5;
  static const int saturday = 1 << 6;
  static const int all = 0x7F;

  static const List<int> bits = [
    sunday,
    monday,
    tuesday,
    wednesday,
    thursday,
    friday,
    saturday,
  ];

  static const List<String> short = [
    'Sun',
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
  ];

  static int bitFor(DateTime day) => 1 << (day.weekday % DateTime.sunday);

  static bool has(int mask, DateTime day) => (mask & bitFor(day)) != 0;

  static int withDay(int mask, DateTime day, {required bool on}) {
    final bit = bitFor(day);
    return on ? (mask | bit) : (mask & ~bit);
  }
}
