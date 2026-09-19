import 'package:shopping_list/apps/calendar/data/calendar_activity.dart';
import 'package:shopping_list/apps/calendar/data/dao/block_dao.dart';
import 'package:shopping_list/apps/calendar/data/dao/location_dao.dart';
import 'package:shopping_list/apps/calendar/data/dao/override_dao.dart';
import 'package:shopping_list/apps/calendar/data/dao/series_dao.dart';
import 'package:shopping_list/apps/calendar/data/expand/days.dart';
import 'package:shopping_list/apps/calendar/data/expand/recurrence.dart';
import 'package:shopping_list/apps/calendar/data/models/block.dart';
import 'package:shopping_list/apps/calendar/data/models/occurrence_override.dart';
import 'package:shopping_list/apps/calendar/data/models/place.dart';
import 'package:shopping_list/apps/calendar/data/models/place_mark.dart';
import 'package:shopping_list/apps/calendar/data/models/series.dart';
import 'package:shopping_list/apps/calendar/data/models/ticket.dart';
import 'package:shopping_list/core/activity/activity_dao.dart';
import 'package:shopping_list/core/activity/activity_entry.dart';
import 'package:shopping_list/core/db/database.dart';
import 'package:shopping_list/core/design/stamp_ink.dart';
import 'package:shopping_list/core/util/normalize.dart';

/// Calendar's public surface. Screens talk to this, never to the DAOs.
class CalendarRepository {
  CalendarRepository(this._db);

  final AppDatabase _db;

  LocationDao get _places => LocationDao(_db.db);
  SeriesDao get _series => SeriesDao(_db.db);
  BlockDao get _blocks => BlockDao(_db.db);
  OverrideDao get _overrides => OverrideDao(_db.db);

  Future<List<Place>> places() => _places.all();

  Future<Place?> place(int id) => _places.byId(id);

  Future<Place> addPlace({
    required String title,
    required double latitude,
    required double longitude,
    String? inkId,
    String? iconId,
  }) async {
    final usedInk = await _places.usedInkIds();
    final usedIcons = await _places.usedIconIds();
    return _places.insert(
      Place(
        title: cleanName(title),
        iconId: iconId ?? PlaceMark.next(usedIcons),
        inkId: inkId ?? StampInk.next(usedInk),
        latitude: latitude,
        longitude: longitude,
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> updatePlace(Place place) =>
      _places.update(place.copyWith(title: cleanName(place.title)));

  Future<void> deletePlace(int id) => _places.delete(id);

  Future<List<Series>> series() => _series.all();

  Future<Series?> seriesById(int id) => _series.byId(id);

  Future<Series> addSeries(Series draft) {
    return _db.db.transaction((txn) async {
      final saved = await SeriesDao(txn).insert(draft);
      await ActivityWriter(txn).write(
        ActivityEntry(
          appId: CalendarActivity.appId,
          kind: CalendarActivity.seriesAdded,
          title: saved.title,
          subtitle: 'On the registry',
          occurredAt: DateTime.now(),
          refTable: CalendarActivity.seriesTable,
          refId: saved.id,
        ),
      );
      return saved;
    });
  }

  Future<void> updateSeries(Series series) => _series.update(series);

  Future<void> setSeriesActive(int id, {required bool active}) async {
    final existing = await _series.byId(id);
    if (existing == null) return;
    await _series.update(existing.copyWith(active: active));
  }

  Future<void> deleteSeries(int id) async {
    await _db.db.transaction((txn) async {
      await ActivityWriter(txn).deleteFor(
        appId: CalendarActivity.appId,
        refTable: CalendarActivity.seriesTable,
        refId: id,
      );
      await SeriesDao(txn).delete(id);
    });
  }

  Future<List<Block>> blocks() => _blocks.all();

  Future<Block?> blockById(int id) => _blocks.byId(id);

  Future<Block> addBlock(Block draft) {
    return _db.db.transaction((txn) async {
      final saved = await BlockDao(txn).insert(draft);
      await ActivityWriter(txn).write(
        ActivityEntry(
          appId: CalendarActivity.appId,
          kind: CalendarActivity.blockAdded,
          title: saved.title,
          subtitle: 'On the fly',
          occurredAt: saved.startsAt,
          refTable: CalendarActivity.blocksTable,
          refId: saved.id,
        ),
      );
      return saved;
    });
  }

  Future<void> updateBlock(Block block) => _blocks.update(block);

  Future<void> deleteBlock(int id) async {
    await _db.db.transaction((txn) async {
      await ActivityWriter(txn).deleteFor(
        appId: CalendarActivity.appId,
        refTable: CalendarActivity.blocksTable,
        refId: id,
      );
      await BlockDao(txn).delete(id);
    });
  }

  Future<List<OccurrenceOverride>> overrides() => _overrides.all();

  Future<void> skipOccurrence({
    required int seriesId,
    required DateTime originalStart,
  }) =>
      _overrides.upsert(
        OccurrenceOverride(
          seriesId: seriesId,
          originalStart: originalStart,
          kind: OverrideKind.skip,
          createdAt: DateTime.now(),
        ),
      );

  Future<void> moveOccurrence({
    required int seriesId,
    required DateTime originalStart,
    required DateTime startsAt,
    int? durationMinutes,
    int? locationId,
    String? title,
    String? note,
    String? inkId,
    String? iconId,
  }) =>
      _overrides.upsert(
        OccurrenceOverride(
          seriesId: seriesId,
          originalStart: originalStart,
          kind: OverrideKind.move,
          startsAt: startsAt,
          durationMinutes: durationMinutes,
          locationId: locationId,
          title: title,
          note: note,
          inkId: inkId,
          iconId: iconId,
          createdAt: DateTime.now(),
        ),
      );

  Future<void> clearOverride({
    required int seriesId,
    required DateTime originalStart,
  }) =>
      _overrides.deleteFor(seriesId: seriesId, originalStart: originalStart);

  Future<List<Ticket>> ticketsOn({
    required DateTime from,
    required DateTime to,
  }) async {
    final paddedFrom = from.subtract(Recurrence.pad);
    final paddedTo = to.add(Recurrence.pad);
    final series = await _series.active();
    final blocks = await _blocks.inRange(paddedFrom, paddedTo);
    final overrides = await _overrides.all();
    return Recurrence.tickets(
      series: series,
      blocks: blocks,
      overrides: overrides,
      from: from,
      to: to,
    );
  }

  Future<List<Ticket>> ticketsOnDay(DateTime day) {
    final start = Days.startOfDay(day);
    return ticketsOn(from: start, to: Days.startOfNextDay(start));
  }

  Future<List<Ticket>> today({DateTime? now}) async {
    final at = now ?? DateTime.now();
    final start = Days.startOfDay(at);
    final tickets = await ticketsOn(from: start, to: Days.startOfNextDay(start));
    return [for (final ticket in tickets) if (ticket.endsAt.isAfter(at)) ticket];
  }

  /// Drag or resize a visible ticket. Registry tickets write a this-time
  /// override; fly tickets update the block.
  Future<void> reschedule(
    Ticket ticket, {
    required DateTime startsAt,
    required int durationMinutes,
  }) async {
    final blockId = ticket.blockId;
    if (blockId != null) {
      final existing = await _blocks.byId(blockId);
      if (existing == null) return;
      await _blocks.update(
        existing.copyWith(startsAt: startsAt, durationMinutes: durationMinutes),
      );
      return;
    }
    final seriesId = ticket.seriesId;
    if (seriesId == null) return;
    await moveOccurrence(
      seriesId: seriesId,
      originalStart: ticket.originalStart,
      startsAt: startsAt,
      durationMinutes: durationMinutes,
      locationId: ticket.locationId,
      title: ticket.title,
      note: ticket.note,
      inkId: ticket.inkId,
      iconId: ticket.iconId,
    );
  }
}
