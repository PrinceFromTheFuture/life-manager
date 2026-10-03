/// Local calendar arithmetic for the blotter.
///
/// Weeks start Sunday — that is the week this life is held in, not the ISO
/// Monday week the gym uses for progress.
///
/// Everything here moves by calendar fields, never by [Duration]. A day is not
/// always 24 hours: adding `Duration(days: 1)` across a DST change lands at
/// 23:00 or 01:00, which silently files a whole week under the wrong Sunday.
abstract final class Days {
  static DateTime startOfDay(DateTime when) =>
      DateTime(when.year, when.month, when.day);

  static DateTime startOfNextDay(DateTime when) => addDays(when, 1);

  /// Local midnight [days] after [when]'s day. Negative goes back.
  static DateTime addDays(DateTime when, int days) =>
      DateTime(when.year, when.month, when.day + days);

  /// Sunday midnight of the week containing [when].
  static DateTime startOfWeek(DateTime when) =>
      addDays(when, -(when.weekday % DateTime.sunday));

  static List<DateTime> weekOf(DateTime when) {
    final start = startOfWeek(when);
    return [for (var i = 0; i < 7; i++) addDays(start, i)];
  }

  /// Whole days from [from] to [to], ignoring the time of day.
  static int between(DateTime from, DateTime to) {
    final a = DateTime.utc(from.year, from.month, from.day);
    final b = DateTime.utc(to.year, to.month, to.day);
    return b.difference(a).inDays;
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

  /// Wall-clock [minutes] after midnight on [day]. 18:00 stays 18:00 on the
  /// day the clocks change.
  static DateTime atMinutes(DateTime day, int minutes) =>
      DateTime(day.year, day.month, day.day, 0, minutes);

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
