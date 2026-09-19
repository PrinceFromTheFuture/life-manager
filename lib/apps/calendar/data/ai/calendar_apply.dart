import 'package:shopping_list/apps/calendar/data/ai/calendar_plan.dart';
import 'package:shopping_list/apps/calendar/data/calendar_repository.dart';
import 'package:shopping_list/apps/calendar/data/expand/days.dart';
import 'package:shopping_list/apps/calendar/data/models/block.dart';
import 'package:shopping_list/apps/calendar/data/models/place.dart';
import 'package:shopping_list/apps/calendar/data/models/ticket.dart';
import 'package:shopping_list/core/util/normalize.dart';

/// Writes a [CalendarPlan] onto the blotter.
///
/// Never touches `calendar_series`. A series ticket becomes a this-time
/// override; a missing place name is ignored rather than created.
class CalendarApply {
  CalendarApply(this._repo);

  final CalendarRepository _repo;

  Future<ApplyResult> run(
    CalendarPlan plan, {
    required List<Place> places,
    required List<Ticket> tickets,
  }) async {
    var created = 0;
    var adjusted = 0;
    var cancelled = 0;
    var ignored = 0;

    final byKey = {for (final ticket in tickets) ticket.key: ticket};

    for (final edit in plan.edits) {
      switch (edit.op) {
        case CalendarOp.create:
          final start = edit.startsAt;
          final title = edit.title?.trim();
          if (start == null || title == null || title.isEmpty) {
            ignored++;
            continue;
          }
          final duration =
              Days.snapDuration(edit.durationMinutes() ?? 60);
          await _repo.addBlock(
            Block(
              title: cleanName(title),
              startsAt: start,
              durationMinutes: duration,
              locationId: _placeId(edit.location, places),
              note: edit.note,
              inkId: edit.ink,
              iconId: edit.icon,
              createdAt: DateTime.now(),
            ),
          );
          created++;
        case CalendarOp.adjust:
          final ticket = await _resolve(edit.ticketKey, byKey);
          if (ticket == null) {
            ignored++;
            continue;
          }
          final start = edit.startsAt ?? ticket.startsAt;
          final duration = Days.snapDuration(
            edit.durationMinutes() ?? ticket.durationMinutes,
          );
          final locationId = edit.location == null
              ? ticket.locationId
              : _placeId(edit.location, places) ?? ticket.locationId;
          if (ticket.blockId != null) {
            final existing = await _repo.blockById(ticket.blockId!);
            if (existing == null) {
              ignored++;
              continue;
            }
            await _repo.updateBlock(
              existing.copyWith(
                title: edit.title ?? existing.title,
                startsAt: start,
                durationMinutes: duration,
                locationId: locationId,
                note: edit.note ?? existing.note,
                inkId: edit.ink ?? existing.inkId,
                iconId: edit.icon ?? existing.iconId,
              ),
            );
            adjusted++;
            continue;
          }
          if (ticket.seriesId == null) {
            ignored++;
            continue;
          }
          await _repo.moveOccurrence(
            seriesId: ticket.seriesId!,
            originalStart: ticket.originalStart,
            startsAt: start,
            durationMinutes: duration,
            locationId: locationId,
            title: edit.title ?? ticket.title,
            note: edit.note ?? ticket.note,
            inkId: edit.ink ?? ticket.inkId,
            iconId: edit.icon ?? ticket.iconId,
          );
          adjusted++;
        case CalendarOp.cancel:
          final ticket = await _resolve(edit.ticketKey, byKey);
          if (ticket == null) {
            ignored++;
            continue;
          }
          if (ticket.blockId != null) {
            await _repo.deleteBlock(ticket.blockId!);
            cancelled++;
            continue;
          }
          if (ticket.seriesId != null) {
            await _repo.skipOccurrence(
              seriesId: ticket.seriesId!,
              originalStart: ticket.originalStart,
            );
            cancelled++;
            continue;
          }
          ignored++;
      }
    }

    return ApplyResult(
      created: created,
      adjusted: adjusted,
      cancelled: cancelled,
      ignored: ignored,
    );
  }

  Future<Ticket?> _resolve(String? key, Map<String, Ticket> byKey) async {
    if (key == null || key.isEmpty) return null;
    final hit = byKey[key];
    if (hit != null) return hit;
    if (key.startsWith('block:')) {
      final id = int.tryParse(key.substring(6));
      if (id == null) return null;
      final block = await _repo.blockById(id);
      if (block == null) return null;
      return Ticket(
        key: key,
        title: block.title,
        startsAt: block.startsAt,
        originalStart: block.startsAt,
        durationMinutes: block.durationMinutes,
        locationId: block.locationId,
        note: block.note,
        inkId: block.inkId,
        iconId: block.iconId,
        blockId: block.id,
      );
    }
    if (key.startsWith('series:')) {
      final parts = key.split(':');
      if (parts.length != 3) return null;
      final seriesId = int.tryParse(parts[1]);
      final millis = int.tryParse(parts[2]);
      if (seriesId == null || millis == null) return null;
      final series = await _repo.seriesById(seriesId);
      if (series == null) return null;
      final original = DateTime.fromMillisecondsSinceEpoch(millis);
      return Ticket(
        key: key,
        title: series.title,
        startsAt: original,
        originalStart: original,
        durationMinutes: series.durationMinutes,
        locationId: series.locationId,
        seriesId: series.id,
      );
    }
    return null;
  }

  static int? _placeId(String? name, List<Place> places) {
    if (name == null || name.trim().isEmpty) return null;
    final want = normalizeName(name);
    for (final place in places) {
      if (normalizeName(place.title) == want) return place.id;
    }
    return null;
  }
}
