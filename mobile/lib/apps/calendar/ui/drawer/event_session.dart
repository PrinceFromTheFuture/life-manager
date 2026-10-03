import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import 'package:shopping_list/apps/calendar/data/expand/days.dart';
import 'package:shopping_list/apps/calendar/data/expand/weekdays.dart';
import 'package:shopping_list/apps/calendar/data/models/series.dart';
import 'package:shopping_list/apps/calendar/data/models/ticket.dart';
import 'package:shopping_list/apps/calendar/state/providers.dart';
import 'package:shopping_list/core/design/paper_snack.dart';

enum RepeatFreq { never, daily, weekly, monthly }

/// How an event repeats, as the form edits it. "Never" is a one-off block;
/// anything else is a routine.
@immutable
class RepeatRule {
  const RepeatRule({
    this.freq = RepeatFreq.never,
    this.interval = 1,
    this.weekdays = 0,
    this.monthDay = 1,
    this.endsOn,
  });

  factory RepeatRule.of(Series series) => RepeatRule(
        freq: switch (series.freq) {
          SeriesFreq.daily => RepeatFreq.daily,
          SeriesFreq.weekly => RepeatFreq.weekly,
          SeriesFreq.monthly => RepeatFreq.monthly,
        },
        interval: series.interval,
        weekdays: series.weekdays == 0 ? Weekdays.bitFor(series.startsOn) : series.weekdays,
        monthDay: series.monthDay,
        endsOn: series.endsOn,
      );

  final RepeatFreq freq;
  final int interval;
  final int weekdays;
  final int monthDay;
  final DateTime? endsOn;

  bool get repeats => freq != RepeatFreq.never;

  SeriesFreq get seriesFreq => switch (freq) {
        RepeatFreq.daily => SeriesFreq.daily,
        RepeatFreq.monthly => SeriesFreq.monthly,
        _ => SeriesFreq.weekly,
      };

  /// Switching to a rule fills in what [on] implies: its weekday for weekly,
  /// its date for monthly.
  RepeatRule withFreq(RepeatFreq next, DateTime on) => RepeatRule(
        freq: next,
        interval: next == freq ? interval : 1,
        weekdays: weekdays == 0 ? Weekdays.bitFor(on) : weekdays,
        monthDay: next == RepeatFreq.monthly && freq != RepeatFreq.monthly ? on.day : monthDay,
        endsOn: next == RepeatFreq.never ? null : endsOn,
      );

  RepeatRule copyWith({
    int? interval,
    int? weekdays,
    int? monthDay,
    DateTime? endsOn,
    bool clearEnd = false,
  }) =>
      RepeatRule(
        freq: freq,
        interval: interval ?? this.interval,
        weekdays: weekdays ?? this.weekdays,
        monthDay: monthDay ?? this.monthDay,
        endsOn: clearEnd ? null : (endsOn ?? this.endsOn),
      );

  /// "Never", "Every day", "Mon, Wed", "Every 2 weeks · Tue", "Monthly on the 4th".
  String describe() {
    final every = interval > 1;
    final base = switch (freq) {
      RepeatFreq.never => 'Never',
      RepeatFreq.daily => every ? 'Every $interval days' : 'Every day',
      RepeatFreq.weekly => () {
          final names = [
            for (var i = 0; i < 7; i++)
              if (weekdays & Weekdays.bits[i] != 0) Weekdays.short[i],
          ];
          final days = names.length == 7 ? 'every day' : names.join(', ');
          return every ? 'Every $interval weeks · $days' : (names.length == 7 ? 'Every day' : days);
        }(),
      RepeatFreq.monthly => '${every ? 'Every $interval months' : 'Monthly'} on the ${_ordinal(monthDay)}',
    };
    final end = endsOn;
    if (!repeats || end == null) return base;
    return '$base · until ${DateFormat('d MMM').format(end)}';
  }

  static String _ordinal(int n) {
    if (n >= 11 && n <= 13) return '${n}th';
    return switch (n % 10) { 1 => '${n}st', 2 => '${n}nd', 3 => '${n}rd', _ => '${n}th' };
  }

  @override
  bool operator ==(Object other) =>
      other is RepeatRule &&
      other.freq == freq &&
      (!repeats ||
          (other.interval == interval &&
              (freq != RepeatFreq.weekly || other.weekdays == weekdays) &&
              (freq != RepeatFreq.monthly || other.monthDay == monthDay) &&
              other.endsOn == endsOn));

  @override
  int get hashCode => Object.hash(freq, interval, weekdays, monthDay, endsOn);
}

/// Where a change to a routine's occurrence lands.
enum EditScope { thisTime, all }

/// Everything one open drawer edits, shared by its views.
///
/// Views read and write fields through [update]; the session knows how the
/// result maps onto the store — a block, one occurrence, or the routine.
class EventSession extends ChangeNotifier {
  EventSession._({
    required this.host,
    required this.controller,
    this.ticket,
    this.series,
    required this.title,
    required this.note,
    required this.startsAt,
    required this.duration,
    required this.locationId,
    required this.inkId,
    required this.iconId,
    required this.repeat,
  })  : _initialStart = startsAt,
        _initialDuration = duration,
        _initialRepeat = repeat,
        _initialTitle = title,
        _initialLocation = locationId;

  factory EventSession.create({
    required BuildContext host,
    required CalendarController controller,
    required DateTime startsAt,
    int duration = 60,
  }) =>
      EventSession._(
        host: host,
        controller: controller,
        title: '',
        note: '',
        startsAt: startsAt,
        duration: duration,
        locationId: null,
        inkId: null,
        iconId: null,
        repeat: const RepeatRule(),
      );

  factory EventSession.edit({
    required BuildContext host,
    required CalendarController controller,
    required Ticket ticket,
    Series? series,
  }) =>
      EventSession._(
        host: host,
        controller: controller,
        ticket: ticket,
        series: series,
        title: ticket.title,
        note: ticket.note ?? '',
        startsAt: ticket.startsAt,
        duration: ticket.durationMinutes,
        locationId: ticket.locationId,
        inkId: ticket.inkId,
        iconId: ticket.iconId,
        repeat: series == null ? const RepeatRule() : RepeatRule.of(series),
      );

  /// A routine on its own, from the routines list. Its next time stands in
  /// for the date the form shows.
  factory EventSession.routine({
    required BuildContext host,
    required CalendarController controller,
    required Series series,
  }) {
    final today = Days.startOfDay(DateTime.now());
    final from = series.startsOn.isAfter(today) ? series.startsOn : today;
    return EventSession._(
      host: host,
      controller: controller,
      series: series,
      title: series.title,
      note: '',
      startsAt: Days.atMinutes(from, series.startMinutes),
      duration: series.durationMinutes,
      locationId: series.locationId,
      inkId: null,
      iconId: null,
      repeat: RepeatRule.of(series),
    );
  }

  /// The screen behind the drawer; snacks land there once the drawer closes.
  final BuildContext host;
  final CalendarController controller;
  final Ticket? ticket;
  final Series? series;

  String title;
  String note;
  DateTime startsAt;
  int duration;
  int? locationId;
  String? inkId;
  String? iconId;
  RepeatRule repeat;
  bool saving = false;

  final DateTime _initialStart;
  final int _initialDuration;
  final RepeatRule _initialRepeat;
  final String _initialTitle;
  final int? _initialLocation;

  void update(void Function(EventSession draft) change) {
    change(this);
    notifyListeners();
  }

  bool get isNew => ticket == null && series == null;

  /// The routine itself, opened from the routines list.
  bool get isRoutine => ticket == null && series != null;

  /// One time of a routine, opened from the grid.
  bool get isOccurrence => ticket?.fromRegistry ?? false;

  /// Routines cannot become one-offs from the form; they are deleted instead.
  bool get canBeOneOff => series == null;

  /// Notes and stamps live on a single time only; routines carry neither.
  bool get carriesStamp => isOccurrence || (!isRoutine && !repeat.repeats);

  bool get canSave => title.trim().isNotEmpty && !saving;

  bool get _routineFieldsChanged =>
      title.trim() != _initialTitle ||
      Days.minutesOf(startsAt) != Days.minutesOf(_initialStart) ||
      duration != _initialDuration ||
      locationId != _initialLocation;

  /// An occurrence edit that could mean this time or every time.
  bool get needsScope =>
      isOccurrence && repeat == _initialRepeat && _routineFieldsChanged;

  DateTime get endsAt => startsAt.add(Duration(minutes: duration));

  String? get _note => note.trim().isEmpty ? null : note.trim();

  /// Write the draft. Occurrences go through [scope]: this time writes an
  /// override, all rewrites the routine. A changed repeat rule always means
  /// the routine.
  Future<void> save({EditScope? scope}) async {
    if (!canSave) return;
    saving = true;
    notifyListeners();
    final name = title.trim();
    final ticket = this.ticket;

    try {
      if (isRoutine) {
        await controller.updateSeries(_seriesDraft(name));
        _snack('Routine updated');
        return;
      }

      if (ticket != null && isOccurrence) {
        final everyTime = repeat != _initialRepeat || scope == EditScope.all;
        if (everyTime && series != null) {
          await controller.updateSeries(_seriesDraft(name, from: ticket));
          if (ticket.overridden) await controller.clearOverride(ticket);
          _snack('Every time · ${repeat.describe()}');
        } else {
          await controller.moveOccurrence(
            ticket,
            startsAt: startsAt,
            durationMinutes: duration,
            locationId: locationId,
            title: name,
            note: _note,
            inkId: inkId,
            iconId: iconId,
          );
          _snack('${DateFormat('EEE HH:mm').format(startsAt)} · This time only');
        }
        return;
      }

      if (ticket != null && ticket.blockId != null) {
        final existing = await controller.ref.read(calendarRepositoryProvider).blockById(ticket.blockId!);
        if (existing == null) return;
        if (repeat.repeats) {
          await controller.addSeries(_seriesDraft(name));
          await controller.deleteBlock(existing.id!);
          _snack('Now a routine · ${repeat.describe()}');
          return;
        }
        await controller.updateBlock(
          existing.copyWith(
            title: name,
            startsAt: startsAt,
            durationMinutes: duration,
            locationId: locationId,
            clearLocation: locationId == null,
            note: note.trim(),
            clearNote: _note == null,
            inkId: inkId,
            clearInk: inkId == null,
            iconId: iconId,
            clearIcon: iconId == null,
          ),
        );
        return;
      }

      if (repeat.repeats) {
        await controller.addSeries(_seriesDraft(name));
        _snack('Routine added · ${repeat.describe()}');
        return;
      }
      await controller.addBlock(
        title: name,
        startsAt: startsAt,
        durationMinutes: duration,
        locationId: locationId,
        note: _note,
        inkId: inkId,
        iconId: iconId,
      );
    } finally {
      saving = false;
      if (hasListeners) notifyListeners();
    }
  }

  Series _seriesDraft(String name, {Ticket? from}) {
    final existing = series;
    var rule = repeat;
    // Moving one Tuesday to Wednesday "for all" moves the routine's day too.
    if (from != null && rule == _initialRepeat && !Days.isSameDay(startsAt, from.startsAt)) {
      if (rule.freq == RepeatFreq.weekly) {
        final mask = Weekdays.withDay(rule.weekdays, from.originalStart, on: false);
        rule = rule.copyWith(weekdays: Weekdays.withDay(mask, startsAt, on: true));
      } else if (rule.freq == RepeatFreq.monthly) {
        rule = rule.copyWith(monthDay: startsAt.day);
      }
    }
    final day = Days.startOfDay(startsAt);
    final startsOn = existing == null || day.isBefore(existing.startsOn) ? day : existing.startsOn;
    return Series(
      id: existing?.id,
      title: name,
      locationId: locationId,
      startMinutes: Days.minutesOf(startsAt),
      durationMinutes: duration,
      freq: rule.seriesFreq,
      interval: rule.interval,
      weekdays: rule.freq == RepeatFreq.weekly
          ? (rule.weekdays == 0 ? Weekdays.bitFor(startsAt) : rule.weekdays)
          : 0,
      monthDay: rule.freq == RepeatFreq.monthly ? rule.monthDay : 1,
      startsOn: startsOn,
      endsOn: rule.endsOn,
      active: existing?.active ?? true,
      createdAt: existing?.createdAt ?? DateTime.now(),
    );
  }

  /// Move to a new time at once, from the detail view's Move.
  Future<void> move(DateTime start, int minutes) async {
    final ticket = this.ticket;
    if (ticket == null) return;
    await controller.reschedule(ticket, startsAt: start, durationMinutes: minutes);
    final label = DateFormat('EEE HH:mm').format(start);
    _snack(
      ticket.fromRegistry ? '$label · This time only' : label,
      undo: () => controller.undoMove(ticket),
    );
  }

  /// Skip this time of a routine, or remove a block. Both can be undone.
  Future<void> remove() async {
    final ticket = this.ticket;
    if (ticket == null) return;
    if (ticket.fromRegistry) {
      await controller.skip(ticket);
      _snack('Skipped ${DateFormat('EEE d MMM').format(ticket.startsAt)}', undo: () => controller.undoMove(ticket));
      return;
    }
    final id = ticket.blockId;
    if (id == null) return;
    final block = await controller.ref.read(calendarRepositoryProvider).blockById(id);
    await controller.deleteBlock(id);
    if (block == null) return;
    _snack(
      '${block.title} removed',
      undo: () => controller.addBlock(
        title: block.title,
        startsAt: block.startsAt,
        durationMinutes: block.durationMinutes,
        locationId: block.locationId,
        note: block.note,
        inkId: block.inkId,
        iconId: block.iconId,
      ),
    );
  }

  Future<void> restore() async {
    final ticket = this.ticket;
    if (ticket == null) return;
    await controller.clearOverride(ticket);
    _snack('Back to the routine');
  }

  Future<void> deleteRoutine() async {
    final id = series?.id;
    if (id == null) return;
    await controller.deleteSeries(id);
    _snack('${series!.title} deleted');
  }

  void _snack(String message, {Future<void> Function()? undo}) {
    if (!host.mounted) return;
    showPaperSnack(
      host,
      message: message,
      actionLabel: undo == null ? null : 'Undo',
      onAction: undo == null ? null : () => unawaited(undo()),
    );
  }
}
