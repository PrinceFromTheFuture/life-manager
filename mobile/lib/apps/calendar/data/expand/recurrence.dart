import 'package:shopping_list/apps/calendar/data/expand/days.dart';
import 'package:shopping_list/apps/calendar/data/expand/weekdays.dart';
import 'package:shopping_list/apps/calendar/data/models/block.dart';
import 'package:shopping_list/apps/calendar/data/models/occurrence_override.dart';
import 'package:shopping_list/apps/calendar/data/models/series.dart';
import 'package:shopping_list/apps/calendar/data/models/ticket.dart';

/// Expands a series into original occurrence starts, then applies overrides.
abstract final class Recurrence {
  /// How far past the visible window we generate so a this-time move onto
  /// the board still lands. Fourteen days covers a week rail plus slack.
  static const Duration pad = Duration(days: 14);

  static const int _maxSteps = 400;

  /// Original starts in `[from, to)`, inclusive of [from] and exclusive of [to].
  static List<DateTime> originalStarts(
    Series series, {
    required DateTime from,
    required DateTime to,
  }) {
    if (!series.active) return const [];
    final startsOn = Days.startOfDay(series.startsOn);
    final endsOn =
        series.endsOn == null ? null : Days.startOfDay(series.endsOn!);
    final windowStart = Days.startOfDay(from);
    final windowEnd = Days.startOfDay(to);
    final interval = series.interval < 1 ? 1 : series.interval;

    final days = switch (series.freq) {
      SeriesFreq.daily => _daily(
          startsOn: startsOn,
          endsOn: endsOn,
          from: windowStart,
          to: windowEnd,
          interval: interval,
        ),
      SeriesFreq.weekly => _weekly(
          startsOn: startsOn,
          endsOn: endsOn,
          from: windowStart,
          to: windowEnd,
          interval: interval,
          weekdays: series.weekdays == 0
              ? Weekdays.bitFor(startsOn)
              : series.weekdays,
        ),
      SeriesFreq.monthly => _monthly(
          startsOn: startsOn,
          endsOn: endsOn,
          from: windowStart,
          to: windowEnd,
          interval: interval,
          monthDay: series.monthDay,
        ),
    };

    return [
      for (final day in days) Days.atMinutes(day, series.startMinutes),
    ];
  }

  /// Visible tickets in `[from, to)`.
  static List<Ticket> tickets({
    required List<Series> series,
    required List<Block> blocks,
    required List<OccurrenceOverride> overrides,
    required DateTime from,
    required DateTime to,
  }) {
    final padFrom = from.subtract(pad);
    final padTo = to.add(pad);
    final byKey = <_OverrideKey, OccurrenceOverride>{
      for (final override in overrides)
        _OverrideKey(override.seriesId, override.originalStart): override,
    };

    final out = <Ticket>[];

    for (final item in series) {
      if (item.id == null || !item.active) continue;
      for (final original in originalStarts(item, from: padFrom, to: padTo)) {
        final override = byKey[_OverrideKey(item.id!, original)];
        if (override?.kind == OverrideKind.skip) continue;
        final ticket = _fromSeries(item, original, override);
        if (!ticket.startsAt.isBefore(to) || !ticket.endsAt.isAfter(from)) {
          continue;
        }
        out.add(ticket);
      }
    }

    for (final block in blocks) {
      if (block.id == null) continue;
      if (!block.startsAt.isBefore(to) || !block.endsAt.isAfter(from)) {
        continue;
      }
      out.add(
        Ticket(
          key: 'block:${block.id}',
          title: block.title,
          startsAt: block.startsAt,
          originalStart: block.startsAt,
          durationMinutes: block.durationMinutes,
          locationId: block.locationId,
          note: block.note,
          inkId: block.inkId,
          iconId: block.iconId,
          blockId: block.id,
        ),
      );
    }

    out.sort((a, b) {
      final byStart = a.startsAt.compareTo(b.startsAt);
      if (byStart != 0) return byStart;
      return a.key.compareTo(b.key);
    });
    return out;
  }

  /// Remaining and in-progress tickets on [now]'s day.
  static List<Ticket> today({
    required List<Series> series,
    required List<Block> blocks,
    required List<OccurrenceOverride> overrides,
    required DateTime now,
  }) {
    final start = Days.startOfDay(now);
    final end = Days.startOfNextDay(now);
    return [
      for (final ticket in tickets(
        series: series,
        blocks: blocks,
        overrides: overrides,
        from: start,
        to: end,
      ))
        if (ticket.endsAt.isAfter(now)) ticket,
    ];
  }

  static Ticket _fromSeries(
    Series series,
    DateTime original,
    OccurrenceOverride? override,
  ) {
    final moved = override?.kind == OverrideKind.move;
    return Ticket(
      key: 'series:${series.id}:${original.millisecondsSinceEpoch}',
      title: (moved ? override?.title : null) ?? series.title,
      startsAt: (moved ? override?.startsAt : null) ?? original,
      originalStart: original,
      durationMinutes:
          (moved ? override?.durationMinutes : null) ?? series.durationMinutes,
      locationId: moved && override != null && override.locationId != null
          ? override.locationId
          : series.locationId,
      note: moved ? override?.note : null,
      inkId: moved ? override?.inkId : null,
      iconId: moved ? override?.iconId : null,
      seriesId: series.id,
      overridden: moved,
    );
  }

  static List<DateTime> _daily({
    required DateTime startsOn,
    required DateTime? endsOn,
    required DateTime from,
    required DateTime to,
    required int interval,
  }) {
    var day = startsOn;
    if (day.isBefore(from)) {
      final skipped = from.difference(day).inDays;
      final steps = (skipped / interval).ceil();
      day = day.add(Duration(days: steps * interval));
    }
    final out = <DateTime>[];
    for (var i = 0; i < _maxSteps && day.isBefore(to); i++) {
      if (endsOn != null && day.isAfter(endsOn)) break;
      if (!day.isBefore(startsOn)) out.add(day);
      day = day.add(Duration(days: interval));
    }
    return out;
  }

  static List<DateTime> _weekly({
    required DateTime startsOn,
    required DateTime? endsOn,
    required DateTime from,
    required DateTime to,
    required int interval,
    required int weekdays,
  }) {
    final origin = Days.startOfWeek(startsOn);
    final out = <DateTime>[];
    var day = from.isBefore(startsOn) ? startsOn : from;
    for (var i = 0; i < _maxSteps && day.isBefore(to); i++) {
      if (endsOn != null && day.isAfter(endsOn)) break;
      if (!day.isBefore(startsOn) && Weekdays.has(weekdays, day)) {
        final weeks = Days.startOfWeek(day).difference(origin).inDays ~/ 7;
        if (weeks % interval == 0) out.add(day);
      }
      day = day.add(const Duration(days: 1));
    }
    return out;
  }

  static List<DateTime> _monthly({
    required DateTime startsOn,
    required DateTime? endsOn,
    required DateTime from,
    required DateTime to,
    required int interval,
    required int monthDay,
  }) {
    var year = startsOn.year;
    var month = startsOn.month;
    var first = Days.dayOf(year, month, monthDay);
    if (first.isBefore(startsOn)) {
      month += interval;
      first = Days.dayOf(year, month, monthDay);
      year = first.year;
      month = first.month;
    }

    final out = <DateTime>[];
    var cursor = first;
    for (var i = 0; i < _maxSteps && cursor.isBefore(to); i++) {
      if (endsOn != null && cursor.isAfter(endsOn)) break;
      if (!cursor.isBefore(from) && !cursor.isBefore(startsOn)) {
        out.add(cursor);
      }
      month += interval;
      cursor = Days.dayOf(year, month, monthDay);
      year = cursor.year;
      month = cursor.month;
    }
    return out;
  }
}

class _OverrideKey {
  const _OverrideKey(this.seriesId, this.original);

  final int seriesId;
  final DateTime original;

  @override
  bool operator ==(Object other) =>
      other is _OverrideKey &&
      other.seriesId == seriesId &&
      other.original.millisecondsSinceEpoch == original.millisecondsSinceEpoch;

  @override
  int get hashCode =>
      Object.hash(seriesId, original.millisecondsSinceEpoch);
}
