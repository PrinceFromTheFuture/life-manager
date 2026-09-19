import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:http/http.dart' as http;
import 'package:shopping_list/apps/calendar/data/ai/calendar_apply.dart';
import 'package:shopping_list/apps/calendar/data/ai/calendar_plan.dart';
import 'package:shopping_list/apps/calendar/data/ai/calendar_scribe.dart';
import 'package:shopping_list/apps/calendar/data/calendar_repository.dart';
import 'package:shopping_list/apps/calendar/data/expand/days.dart';
import 'package:shopping_list/apps/calendar/data/models/block.dart';
import 'package:shopping_list/apps/calendar/data/models/place.dart';
import 'package:shopping_list/apps/calendar/data/models/series.dart';
import 'package:shopping_list/apps/calendar/data/models/ticket.dart';
import 'package:shopping_list/core/activity/providers.dart';
import 'package:shopping_list/core/providers.dart';
import 'package:shopping_list/core/settings/api_keys.dart';

final calendarRepositoryProvider = Provider<CalendarRepository>(
  (ref) => CalendarRepository(ref.watch(databaseProvider)),
);

/// Bumped after every write so the board, registry and places refresh.
final calendarTickProvider = StateProvider<int>((ref) => 0);

final calendarTabProvider = StateProvider<int>((ref) => 0);

final boardDayProvider = StateProvider<DateTime>(
  (ref) => DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  ),
);

enum BoardGrain { day, week }

final boardGrainProvider = StateProvider<BoardGrain>((ref) => BoardGrain.day);

final weekTicketsProvider =
    FutureProvider.autoDispose.family<List<Ticket>, DateTime>((ref, day) {
  ref.watch(calendarTickProvider);
  final start = Days.startOfWeek(day);
  return ref.watch(calendarRepositoryProvider).ticketsOn(
        from: start,
        to: start.add(const Duration(days: 7)),
      );
});

final placesProvider = FutureProvider<List<Place>>((ref) {
  ref.watch(calendarTickProvider);
  return ref.watch(calendarRepositoryProvider).places();
});

final seriesProvider = FutureProvider<List<Series>>((ref) {
  ref.watch(calendarTickProvider);
  return ref.watch(calendarRepositoryProvider).series();
});

final todayTicketsProvider = FutureProvider<List<Ticket>>((ref) {
  ref.watch(calendarTickProvider);
  return ref.watch(calendarRepositoryProvider).today();
});

final dayTicketsProvider =
    FutureProvider.autoDispose.family<List<Ticket>, DateTime>((ref, day) {
  ref.watch(calendarTickProvider);
  return ref.watch(calendarRepositoryProvider).ticketsOnDay(day);
});

class CalendarController {
  CalendarController(this.ref);

  final Ref ref;

  CalendarRepository get _repo => ref.read(calendarRepositoryProvider);

  void _tick() {
    ref.read(calendarTickProvider.notifier).state++;
    ref.invalidate(activityFeedProvider);
  }

  Future<Place> addPlace({
    required String title,
    required double latitude,
    required double longitude,
    String? inkId,
    String? iconId,
  }) async {
    final place = await _repo.addPlace(
      title: title,
      latitude: latitude,
      longitude: longitude,
      inkId: inkId,
      iconId: iconId,
    );
    _tick();
    return place;
  }

  Future<void> updatePlace(Place place) async {
    await _repo.updatePlace(place);
    _tick();
  }

  Future<void> deletePlace(int id) async {
    await _repo.deletePlace(id);
    _tick();
  }

  Future<Series> addSeries(Series draft) async {
    final saved = await _repo.addSeries(draft);
    _tick();
    return saved;
  }

  Future<void> updateSeries(Series series) async {
    await _repo.updateSeries(series);
    _tick();
  }

  Future<void> setSeriesActive(int id, {required bool active}) async {
    await _repo.setSeriesActive(id, active: active);
    _tick();
  }

  Future<void> deleteSeries(int id) async {
    await _repo.deleteSeries(id);
    _tick();
  }

  Future<Block> addBlock({
    required String title,
    required DateTime startsAt,
    required int durationMinutes,
    int? locationId,
    String? note,
    String? inkId,
    String? iconId,
  }) async {
    final saved = await _repo.addBlock(
      Block(
        title: title,
        startsAt: startsAt,
        durationMinutes: durationMinutes,
        locationId: locationId,
        note: note,
        inkId: inkId,
        iconId: iconId,
        createdAt: DateTime.now(),
      ),
    );
    _tick();
    return saved;
  }

  Future<void> updateBlock(Block block) async {
    await _repo.updateBlock(block);
    _tick();
  }

  Future<void> deleteBlock(int id) async {
    await _repo.deleteBlock(id);
    _tick();
  }

  Future<void> skip(Ticket ticket) async {
    final seriesId = ticket.seriesId;
    if (seriesId == null) return;
    await _repo.skipOccurrence(
      seriesId: seriesId,
      originalStart: ticket.originalStart,
    );
    _tick();
  }

  Future<void> reschedule(
    Ticket ticket, {
    required DateTime startsAt,
    required int durationMinutes,
  }) async {
    await _repo.reschedule(
      ticket,
      startsAt: startsAt,
      durationMinutes: durationMinutes,
    );
    _tick();
  }

  Future<void> moveOccurrence(
    Ticket ticket, {
    required DateTime startsAt,
    required int durationMinutes,
    int? locationId,
    String? title,
    String? note,
    String? inkId,
    String? iconId,
  }) async {
    final seriesId = ticket.seriesId;
    if (seriesId == null) return;
    await _repo.moveOccurrence(
      seriesId: seriesId,
      originalStart: ticket.originalStart,
      startsAt: startsAt,
      durationMinutes: durationMinutes,
      locationId: locationId,
      title: title,
      note: note,
      inkId: inkId,
      iconId: iconId,
    );
    _tick();
  }

  /// Ask the scribe, then write only blotter edits. Never touches the registry.
  Future<ApplyResult> ask({
    required String request,
    required DateTime day,
    http.Client? client,
  }) async {
    final reply = await converse(
      request: request,
      day: day,
      history: const [],
      client: client,
    );
    return reply.result;
  }

  /// One chat turn: short prose plus typed edits, then apply.
  Future<({CalendarReply reply, ApplyResult result})> converse({
    required String request,
    required DateTime day,
    List<Map<String, String>> history = const [],
    http.Client? client,
  }) async {
    final key = await ref.read(apiKeyStoreProvider).read(ApiKeyKind.openRouter);
    if (key == null || key.isEmpty) {
      throw CalendarScribeException(
        'Add the OpenRouter key in Settings.',
      );
    }
    final now = DateTime.now();
    final weekStart = Days.startOfWeek(day);
    final places = await _repo.places();
    final tickets = await _repo.ticketsOn(
      from: weekStart,
      to: weekStart.add(const Duration(days: 7)),
    );
    final reply = await CalendarScribe(key, client: client).chat(
      request: request,
      history: history,
      now: now,
      day: day,
      places: places,
      tickets: tickets,
    );
    final result = await CalendarApply(_repo).run(
      reply.plan,
      places: places,
      tickets: tickets,
    );
    if (result.changed > 0) _tick();
    return (reply: reply, result: result);
  }

  Future<void> clearOverride(Ticket ticket) async {
    final seriesId = ticket.seriesId;
    if (seriesId == null) return;
    await _repo.clearOverride(
      seriesId: seriesId,
      originalStart: ticket.originalStart,
    );
    _tick();
  }
}

final calendarControllerProvider =
    Provider<CalendarController>((ref) => CalendarController(ref));
