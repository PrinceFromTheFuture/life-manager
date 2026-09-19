import 'package:intl/intl.dart';

import 'package:shopping_list/apps/calendar/data/expand/weekdays.dart';
import 'package:shopping_list/apps/calendar/data/models/series.dart';

/// Times and series, spoken the way a timetable prints them.
abstract final class Clock {
  static final DateFormat _hm = DateFormat('HH:mm');
  static final DateFormat _day = DateFormat('EEE d MMM');

  static String hm(DateTime when) => _hm.format(when);

  static String minutes(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  static String day(DateTime when) => _day.format(when);

  static String span(DateTime start, int durationMinutes) {
    final end = start.add(Duration(minutes: durationMinutes));
    return '${hm(start)}–${hm(end)}';
  }

  static String seriesRule(Series series) {
    final time = minutes(series.startMinutes);
    final every = series.interval == 1 ? '' : 'every ${series.interval} ';
    return switch (series.freq) {
      SeriesFreq.daily => '${every.isEmpty ? 'Every day' : '${every}days'} · $time',
      SeriesFreq.weekly =>
        '${every.isEmpty ? '' : every}'
            '${_weeklyDays(series)} · $time',
      SeriesFreq.monthly =>
        '${every.isEmpty ? 'Monthly' : '${every}months'} · the ${series.monthDay} · $time',
    };
  }

  static String _weeklyDays(Series series) {
    final mask =
        series.weekdays == 0 ? Weekdays.bitFor(series.startsOn) : series.weekdays;
    final names = [
      for (var i = 0; i < 7; i++)
        if (mask & Weekdays.bits[i] != 0) Weekdays.short[i],
    ];
    if (names.length == 7) return 'Every day';
    return names.join(', ');
  }
}
