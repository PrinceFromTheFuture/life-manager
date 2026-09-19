import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shopping_list/apps/calendar/data/clock.dart';
import 'package:shopping_list/apps/calendar/data/expand/days.dart';
import 'package:shopping_list/apps/calendar/data/expand/recurrence.dart';
import 'package:shopping_list/apps/calendar/data/models/place.dart';
import 'package:shopping_list/apps/calendar/data/models/place_mark.dart';
import 'package:shopping_list/apps/calendar/data/models/series.dart';
import 'package:shopping_list/apps/calendar/data/models/ticket.dart';
import 'package:shopping_list/core/design/stamp_ink.dart';
import 'package:shopping_list/core/design/widgets/ink_pad.dart';
import 'package:shopping_list/apps/calendar/state/providers.dart';
import 'package:shopping_list/apps/calendar/ui/places/place_picker.dart';
import 'package:shopping_list/apps/calendar/ui/registry/series_sheet.dart';
import 'package:shopping_list/apps/receipts/ui/widgets/sheet_parts.dart';
import 'package:shopping_list/core/design/paper_snack.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/design/widgets/app_icon.dart';

/// Write a fly ticket, or correct this time on a registry ticket.
class EventSheet extends ConsumerStatefulWidget {
  const EventSheet({
    super.key,
    this.ticket,
    this.day,
    this.startsAt,
  });

  final Ticket? ticket;
  final DateTime? day;
  final DateTime? startsAt;

  static Future<void> open(
    BuildContext context, {
    Ticket? ticket,
    DateTime? day,
    DateTime? startsAt,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => EventSheet(ticket: ticket, day: day, startsAt: startsAt),
      ),
    );
  }

  @override
  ConsumerState<EventSheet> createState() => _EventSheetState();
}

class _EventSheetState extends ConsumerState<EventSheet> {
  late final TextEditingController _title;
  late final TextEditingController _note;
  late DateTime _startsAt;
  late int _duration;
  int? _locationId;
  String? _inkId;
  String? _iconId;
  bool _fromRegistry = false;
  Series? _series;
  bool _saving = false;

  bool get _editing => widget.ticket != null;

  @override
  void initState() {
    super.initState();
    final ticket = widget.ticket;
    final day = Days.startOfDay(
      widget.startsAt ?? widget.day ?? ticket?.startsAt ?? DateTime.now(),
    );
    final now = DateTime.now();
    _title = TextEditingController(text: ticket?.title ?? '');
    _note = TextEditingController(text: ticket?.note ?? '');
    _startsAt = ticket?.startsAt ??
        widget.startsAt ??
        Days.atMinutes(day, Days.snapMinutes(Days.minutesOf(now)));
    _duration = ticket?.durationMinutes ?? 60;
    _locationId = ticket?.locationId;
    _inkId = ticket?.inkId;
    _iconId = ticket?.iconId;
    _fromRegistry = ticket?.fromRegistry ?? false;
    _title.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  bool get _canSave => _title.text.trim().isNotEmpty && !_saving;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startsAt,
      firstDate: DateTime(2020),
      lastDate: DateTime(DateTime.now().year + 8),
      useRootNavigator: false,
    );
    if (picked == null) return;
    setState(() {
      _startsAt = Days.atMinutes(picked, Days.minutesOf(_startsAt));
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startsAt),
      useRootNavigator: false,
    );
    if (picked == null) return;
    setState(() {
      _startsAt = DateTime(
        _startsAt.year,
        _startsAt.month,
        _startsAt.day,
        picked.hour,
        picked.minute,
      );
    });
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);
    final controller = ref.read(calendarControllerProvider);
    final title = _title.text.trim();
    final ticket = widget.ticket;

    if (ticket != null && ticket.fromRegistry) {
      await controller.moveOccurrence(
        ticket,
        startsAt: _startsAt,
        durationMinutes: _duration,
        locationId: _locationId,
        title: title,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        inkId: _inkId,
        iconId: _iconId,
      );
      if (mounted) {
        showPaperSnack(
          context,
          message: 'This time. The series is unchanged.',
          actionLabel: 'The series',
          onAction: () {
            final series = (ref.read(seriesProvider).valueOrNull ?? const [])
                .where((s) => s.id == ticket.seriesId)
                .firstOrNull;
            if (series != null) SeriesSheet.open(context, existing: series);
          },
        );
        Navigator.of(context).pop();
      }
      return;
    }

    if (ticket != null && ticket.blockId != null) {
      final existing =
          await ref.read(calendarRepositoryProvider).blockById(ticket.blockId!);
      if (existing != null) {
        await controller.updateBlock(
          existing.copyWith(
            title: title,
            startsAt: _startsAt,
            durationMinutes: _duration,
            locationId: _locationId,
            clearLocation: _locationId == null,
            note: _note.text.trim(),
            clearNote: _note.text.trim().isEmpty,
            inkId: _inkId,
            clearInk: _inkId == null,
            iconId: _iconId,
            clearIcon: _iconId == null,
          ),
        );
      }
      if (mounted) Navigator.of(context).pop();
      return;
    }

    if (_fromRegistry && _series != null) {
      final day = Days.startOfDay(_startsAt);
      final lands = Recurrence.originalStarts(
        _series!,
        from: day,
        to: Days.startOfNextDay(day),
      );
      if (lands.isNotEmpty) {
        final original = lands.first;
        final synthetic = Ticket(
          key: 'series:${_series!.id}:${original.millisecondsSinceEpoch}',
          title: _series!.title,
          startsAt: original,
          originalStart: original,
          durationMinutes: _series!.durationMinutes,
          locationId: _series!.locationId,
          seriesId: _series!.id,
        );
        await controller.moveOccurrence(
          synthetic,
          startsAt: _startsAt,
          durationMinutes: _duration,
          locationId: _locationId,
          title: title,
          note: _note.text.trim().isEmpty ? null : _note.text.trim(),
          inkId: _inkId,
          iconId: _iconId,
        );
        if (mounted) Navigator.of(context).pop();
        return;
      }
    }

    await controller.addBlock(
      title: title,
      startsAt: _startsAt,
      durationMinutes: _duration,
      locationId: _locationId,
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      inkId: _inkId,
      iconId: _iconId,
    );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final ticket = widget.ticket;
    if (ticket == null) return;
    if (ticket.fromRegistry) {
      await ref.read(calendarControllerProvider).skip(ticket);
    } else if (ticket.blockId != null) {
      await ref.read(calendarControllerProvider).deleteBlock(ticket.blockId!);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    final places = ref.watch(placesProvider).valueOrNull ?? const <Place>[];
    final place = places.where((p) => p.id == _locationId).firstOrNull;
    final allSeries = ref.watch(seriesProvider).valueOrNull ?? const <Series>[];
    final ticket = widget.ticket;

    return Scaffold(
      backgroundColor: palette.paper,
      appBar: AppBar(
        title: Text(_editing ? 'Ticket' : 'New event'),
        actions: [
          TextButton(
            onPressed: _canSave ? _save : null,
            child: Text(_editing ? 'Save' : 'Add'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(Space.lg),
        children: [
          TextField(
            controller: _title,
            autofocus: !_editing,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'What happens',
              hintText: 'Gym, shift, dinner…',
            ),
          ),
          const SizedBox(height: Space.xl),
          SheetBlock(
            label: 'When',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: _pickDate,
                  child: Text(
                    Clock.day(_startsAt),
                    style: Type.item.copyWith(color: palette.print),
                  ),
                ),
                const SizedBox(height: Space.sm),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _pickTime,
                        child: Text(
                          Clock.hm(_startsAt),
                          style: Type.totalDisplay.copyWith(
                            fontSize: 32,
                            color: palette.print,
                          ),
                        ),
                      ),
                    ),
                    Text(
                      '$_duration min',
                      style: Type.monoBold.copyWith(color: palette.faded),
                    ),
                    IconButton(
                      onPressed: _duration > 15
                          ? () => setState(() => _duration -= 15)
                          : null,
                      icon: const AppIcon(SolarIcons.MinusCircle, size: 20),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _duration += 15),
                      icon: const AppIcon(SolarIcons.AddCircle, size: 20),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SheetBlock(
            label: 'Note',
            child: TextField(
              controller: _note,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Optional',
                border: InputBorder.none,
              ),
            ),
          ),
          SheetBlock(
            label: 'Mark',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: Space.sm,
                  runSpacing: Space.sm,
                  children: [
                    for (final ink in StampInk.all.take(8))
                      StampInkPad(
                        ink: ink,
                        selected: ink.id == _inkId,
                        showLabel: false,
                        onTap: () => setState(
                          () => _inkId = _inkId == ink.id ? null : ink.id,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: Space.sm),
                Wrap(
                  spacing: Space.xs,
                  children: [
                    for (final mark in PlaceMark.all.take(8))
                      InkWell(
                        onTap: () => setState(
                          () => _iconId = _iconId == mark.id ? null : mark.id,
                        ),
                        child: AppIcon(
                          mark.icon,
                          size: 18,
                          color: _iconId == mark.id
                              ? palette.print
                              : palette.faded,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          SheetBlock(
            label: 'Place',
            child: InkWell(
              onTap: () async {
                final id = await showPlacePicker(context, selectedId: _locationId);
                if (id == null) return;
                setState(() => _locationId = id == 0 ? null : id);
              },
              child: Text(
                place?.title ?? 'None',
                style: Type.item.copyWith(
                  color: place == null ? palette.faded : palette.print,
                ),
              ),
            ),
          ),
          if (!_editing) ...[
            SheetBlock(
              label: 'How',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ChoiceChip(
                        label: const Text('On the fly'),
                        selected: !_fromRegistry,
                        onSelected: (_) => setState(() {
                          _fromRegistry = false;
                          _series = null;
                        }),
                      ),
                      const SizedBox(width: Space.sm),
                      ChoiceChip(
                        label: const Text('From the registry'),
                        selected: _fromRegistry,
                        onSelected: (_) => setState(() => _fromRegistry = true),
                      ),
                    ],
                  ),
                  if (_fromRegistry) ...[
                    const SizedBox(height: Space.md),
                    if (allSeries.isEmpty)
                      Text(
                        'The registry is empty. Add a series first.',
                        style: Type.body.copyWith(color: palette.faded),
                      )
                    else
                      for (final series in allSeries)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(series.title),
                          subtitle: Text(Clock.seriesRule(series)),
                          selected: _series?.id == series.id,
                          onTap: () => setState(() {
                            _series = series;
                            _title.text = series.title;
                            _duration = series.durationMinutes;
                            _locationId = series.locationId;
                            _startsAt = Days.atMinutes(
                              _startsAt,
                              series.startMinutes,
                            );
                          }),
                        ),
                  ],
                ],
              ),
            ),
          ],
          if (ticket != null && ticket.fromRegistry) ...[
            Text(
              ticket.overridden
                  ? 'This time is an override. The series is unchanged.'
                  : 'Saving writes this time only.',
              style: Type.caption.copyWith(color: palette.faded),
            ),
            const SizedBox(height: Space.md),
            TextButton(
              onPressed: () {
                final series = allSeries
                    .where((s) => s.id == ticket.seriesId)
                    .firstOrNull;
                if (series != null) SeriesSheet.open(context, existing: series);
              },
              child: const Text('The series'),
            ),
            if (ticket.overridden)
              TextButton(
                onPressed: () async {
                  await ref.read(calendarControllerProvider).clearOverride(ticket);
                  if (!context.mounted) return;
                  Navigator.of(context).pop();
                },
                child: const Text('Restore this time'),
              ),
          ],
          if (_editing) ...[
            const SizedBox(height: Space.lg),
            TextButton(
              onPressed: _delete,
              child: Text(
                ticket!.fromRegistry ? 'Skip this time' : 'Remove',
                style: Type.body.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
