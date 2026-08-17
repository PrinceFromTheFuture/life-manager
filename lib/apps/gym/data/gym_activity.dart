/// Identifiers the gym app writes into the shared feed.
abstract final class GymActivity {
  /// Must match `GymApp.id`; persisted in `activity.app_id`.
  static const String appId = 'gym';

  static const String dayPass = 'day_pass';

  /// Not a real table — the day *is* the session, keyed as yyyymmdd.
  static const String daysRef = 'gym_days';

  /// Calendar day as a stable integer: 13 Aug 2026 -> 20260813.
  static int dayKey(DateTime date) {
    final local = date.toLocal();
    return local.year * 10000 + local.month * 100 + local.day;
  }

  static DateTime dateFromKey(int key) {
    final year = key ~/ 10000;
    final month = (key ~/ 100) % 100;
    final day = key % 100;
    return DateTime(year, month, day);
  }

  static DateTime startOfDay(DateTime date) {
    final local = date.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  static DateTime startOfNextDay(DateTime date) =>
      startOfDay(date).add(const Duration(days: 1));

  /// Monday of the week containing [date], local midnight.
  static DateTime startOfWeek(DateTime date) {
    final day = startOfDay(date);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }
}
