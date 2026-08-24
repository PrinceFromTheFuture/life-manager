/// Calendar arithmetic shared by statement cycles and standing orders.
///
/// Both features let you pick any day from 1 to 31, and both then have to
/// answer what that means in February. They answer it the same way, so the rule
/// lives in one place.
abstract final class Calendar {
  static int daysIn(int year, int month) => DateTime(year, month + 1, 0).day;

  /// Local midnight on [day] of the given month, with days past the end of a
  /// short month falling back to its last day. The 31st in February is the
  /// 28th, or the 29th in a leap year.
  static DateTime dayOf(int year, int month, int day) {
    // Normalise first: callers pass month 0 and 13 freely when stepping.
    final normalised = DateTime(year, month);
    final last = daysIn(normalised.year, normalised.month);
    return DateTime(
      normalised.year,
      normalised.month,
      day < 1 ? 1 : (day > last ? last : day),
    );
  }

  /// Strips the time, so two instants on the same day compare equal.
  static DateTime startOfDay(DateTime when) =>
      DateTime(when.year, when.month, when.day);

  static DateTime startOfMonth(DateTime when) =>
      DateTime(when.year, when.month);

  /// Monday of the week containing [when], local midnight — same week the
  /// gym uses, so the two apps agree what "this week" means.
  static DateTime startOfWeek(DateTime when) {
    final day = startOfDay(when);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
