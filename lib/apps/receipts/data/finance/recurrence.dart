import 'package:shopping_list/apps/receipts/data/finance/calendar.dart';
import 'package:shopping_list/apps/receipts/data/models/recurring_rule.dart';

/// When a standing order should have run.
abstract final class Recurrence {
  /// Twenty years of monthly dates. A rule with a start date set far in the
  /// past should not be able to spend the launch writing thousands of slips.
  static const int _maxMonths = 240;

  /// Every date a rule was due on, strictly after `lastRunOn` and no later than
  /// today. Oldest first.
  ///
  /// The whole idempotency story is this method plus `last_run_on`: nothing is
  /// due twice because the window always opens after the last date written.
  static List<DateTime> datesDue(RecurringRule rule, {required DateTime now}) {
    if (!rule.active) return const [];

    final today = Calendar.startOfDay(now);
    final startsOn = Calendar.startOfDay(rule.startsOn);
    final endsOn =
        rule.endsOn == null ? null : Calendar.startOfDay(rule.endsOn!);
    final lastRun =
        rule.lastRunOn == null ? null : Calendar.startOfDay(rule.lastRunOn!);

    // Begin in the month of whichever boundary is later: a rule that has run
    // before resumes from there, one that never has starts at its start date.
    var cursor = startsOn;
    if (lastRun != null && lastRun.isAfter(cursor)) cursor = lastRun;

    final due = <DateTime>[];

    for (var i = 0; i < _maxMonths; i++) {
      final date = Calendar.dayOf(
        cursor.year,
        cursor.month + i,
        rule.dayOfMonth,
      );

      if (date.isAfter(today)) break;
      if (endsOn != null && date.isAfter(endsOn)) break;
      if (date.isBefore(startsOn)) continue;
      if (lastRun != null && !date.isAfter(lastRun)) continue;

      due.add(date);
    }

    return due;
  }

  /// The next date a rule will run, for the standing order row. Null once the
  /// rule has passed its end date or been paused.
  static DateTime? nextRun(RecurringRule rule, {required DateTime now}) {
    if (!rule.active) return null;

    final today = Calendar.startOfDay(now);
    final startsOn = Calendar.startOfDay(rule.startsOn);
    final endsOn =
        rule.endsOn == null ? null : Calendar.startOfDay(rule.endsOn!);

    // A rule that has not started yet counts from its start date, not from
    // today, or a standing order set up for next quarter would read as dead.
    final from = startsOn.isAfter(today) ? startsOn : today;

    for (var i = 0; i <= 1; i++) {
      final date = Calendar.dayOf(from.year, from.month + i, rule.dayOfMonth);
      if (date.isBefore(from)) continue;
      if (endsOn != null && date.isAfter(endsOn)) return null;
      return date;
    }

    return null;
  }
}
