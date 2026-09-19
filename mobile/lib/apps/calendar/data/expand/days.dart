/// Local calendar arithmetic for the blotter.
///
/// Weeks start Sunday — that is the week this life is held in, not the ISO
/// Monday week the gym uses for progress.
abstract final class Days {
  static DateTime startOfDay(DateTime when) =>
      DateTime(when.year, when.month, when.day);

  static DateTime startOfNextDay(DateTime when) =>
      startOfDay(when).add(const Duration(days: 1));

  /// Sunday midnight of the week containing [when].
  static DateTime startOfWeek(DateTime when) {
    final day = startOfDay(when);
    return day.subtract(Duration(days: day.weekday % DateTime.sunday));
  }

  static List<DateTime> weekOf(DateTime when) {
    final start = startOfWeek(when);
    return [for (var i = 0; i < 7; i++) start.add(Duration(days: i))];
  }

  /// Local midnight on [day] of the given month. Days past the end of a short
  /// month fall back to its last day — the 31st in February is the 28th.
  static DateTime dayOf(int year, int month, int day) {
    final normalised = DateTime(year, month);
    final last = DateTime(normalised.year, normalised.month + 1, 0).day;
    return DateTime(
      normalised.year,
      normalised.month,
      day < 1 ? 1 : (day > last ? last : day),
    );
  }

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static int minutesOf(DateTime when) => when.hour * 60 + when.minute;

  static DateTime atMinutes(DateTime day, int minutes) =>
      startOfDay(day).add(Duration(minutes: minutes));

  /// Snap to a [step]-minute grid. Clamped so a ticket cannot start in the
  /// last incomplete slot of the day.
  static int snapMinutes(int minutes, {int step = 15}) {
    final snapped = ((minutes / step).round() * step);
    final last = (24 * 60) - step;
    if (snapped < 0) return 0;
    if (snapped > last) return last;
    return snapped;
  }

  static int snapDuration(int minutes, {int step = 15, int min = 15}) {
    final snapped = ((minutes / step).round() * step);
    return snapped < min ? min : snapped;
  }
}
