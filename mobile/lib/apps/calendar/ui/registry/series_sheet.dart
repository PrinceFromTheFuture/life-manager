import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shopping_list/apps/calendar/data/clock.dart';
import 'package:shopping_list/apps/calendar/data/expand/days.dart';
import 'package:shopping_list/apps/calendar/data/expand/weekdays.dart';
import 'package:shopping_list/apps/calendar/data/models/place.dart';
import 'package:shopping_list/apps/calendar/data/models/series.dart';
import 'package:shopping_list/apps/calendar/state/providers.dart';
import 'package:shopping_list/apps/calendar/ui/places/place_picker.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/apps/receipts/ui/widgets/sheet_parts.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/design/widgets/app_icon.dart';

/// A registered event: when it happens, how often, and where.
class SeriesSheet extends ConsumerStatefulWidget {
  const SeriesSheet({super.key, this.existing});

  final Series? existing;

  static Future<void> open(BuildContext context, {Series? existing}) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => SeriesSheet(existing: existing),
      ),
    );
  }

  @override
  ConsumerState<SeriesSheet> createState() => _SeriesSheetState();
}

class _SeriesSheetState extends ConsumerState<SeriesSheet> {
  late final TextEditingController _title;
  late int _startMinutes;
  late int _duration;
  late SeriesFreq _freq;
  late int _interval;
  late int _weekdays;
  late int _monthDay;
  late DateTime _startsOn;
  DateTime? _endsOn;
  int? _locationId;
  bool _saving = false;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    final now = DateTime.now();
    _title = TextEditingController(text: existing?.title ?? '');
    _startMinutes = existing?.startMinutes ?? Days.snapMinutes(Days.minutesOf(now));
    _duration = existing?.durationMinutes ?? 60;
    _freq = existing?.freq ?? SeriesFreq.weekly;
    _interval = existing?.interval ?? 1;
    _weekdays = existing?.weekdays == 0 || existing == null
        ? Weekdays.bitFor(now)
        : existing.weekdays;
    _monthDay = existing?.monthDay ?? now.day;
    _startsOn = existing?.startsOn ?? Days.startOfDay(now);
    _endsOn = existing?.endsOn;
    _locationId = existing?.locationId;
    _title.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  bool get _canSave => _title.text.trim().isNotEmpty && !_saving;

  Future<void> _pickStart() async {
    final initial = Days.atMinutes(DateTime.now(), _startMinutes);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      useRootNavigator: false,
    );
    if (picked == null) return;
    setState(() => _startMinutes = picked.hour * 60 + picked.minute);
  }

  Future<void> _pickDate({required bool start}) async {
    final initial = start ? _startsOn : (_endsOn ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(DateTime.now().year + 20),
      useRootNavigator: false,
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _startsOn = Days.startOfDay(picked);
      } else {
        _endsOn = Days.startOfDay(picked);
      }
    });
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);
    final draft = Series(
      id: widget.existing?.id,
      title: _title.text.trim(),
      locationId: _locationId,
      startMinutes: _startMinutes,
      durationMinutes: _duration,
      freq: _freq,
      interval: _interval,
      weekdays: _weekdays,
      monthDay: _monthDay,
      startsOn: _startsOn,
      endsOn: _endsOn,
      active: widget.existing?.active ?? true,
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
    );
    final controller = ref.read(calendarControllerProvider);
    if (_editing) {
      await controller.updateSeries(draft);
    } else {
      await controller.addSeries(draft);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    final places = ref.watch(placesProvider).valueOrNull ?? const <Place>[];
    final place = places.where((p) => p.id == _locationId).firstOrNull;

    return Scaffold(
      backgroundColor: palette.paper,
      appBar: AppBar(
        title: Text(_editing ? 'On the registry' : 'Add to registry'),
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
              labelText: 'What keeps happening',
              hintText: 'Gym, shift, dinner with parents…',
            ),
          ),
          const SizedBox(height: Space.xl),
          SheetBlock(
            label: 'When',
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _pickStart,
                    child: Text(
                      Clock.minutes(_startMinutes),
                      style: Type.totalDisplay.copyWith(
                        fontSize: 32,
                        color: palette.print,
                      ),
                    ),
                  ),
                ),
                _Step(
                  label: '$_duration min',
                  onMinus: _duration > 15
                      ? () => setState(() => _duration -= 15)
                      : null,
                  onPlus: () => setState(() => _duration += 15),
                ),
              ],
            ),
          ),
          SheetBlock(
            label: 'Repeats',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: Space.sm,
                  children: [
                    for (final freq in SeriesFreq.values)
                      ChoiceChip(
                        label: Text(freq.name),
                        selected: _freq == freq,
                        onSelected: (_) => setState(() => _freq = freq),
                      ),
                  ],
                ),
                if (_freq == SeriesFreq.weekly) ...[
                  const SizedBox(height: Space.md),
                  Wrap(
                    spacing: Space.xs,
                    children: [
                      for (var i = 0; i < 7; i++)
                        FilterChip(
                          label: Text(Weekdays.short[i]),
                          selected: _weekdays & Weekdays.bits[i] != 0,
                          onSelected: (on) => setState(() {
                            _weekdays = on
                                ? _weekdays | Weekdays.bits[i]
                                : _weekdays & ~Weekdays.bits[i];
                            if (_weekdays == 0) _weekdays = Weekdays.bits[i];
                          }),
                        ),
                    ],
                  ),
                ],
                if (_freq == SeriesFreq.monthly) ...[
                  const SizedBox(height: Space.md),
                  Row(
                    children: [
                      Text('Day', style: Type.body.copyWith(color: palette.faded)),
                      const Spacer(),
                      _Step(
                        label: '$_monthDay',
                        onMinus: _monthDay > 1
                            ? () => setState(() => _monthDay--)
                            : null,
                        onPlus: _monthDay < 31
                            ? () => setState(() => _monthDay++)
                            : null,
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: Space.md),
                Row(
                  children: [
                    Text('Interval', style: Type.body.copyWith(color: palette.faded)),
                    const Spacer(),
                    _Step(
                      label: '$_interval',
                      onMinus: _interval > 1
                          ? () => setState(() => _interval--)
                          : null,
                      onPlus: () => setState(() => _interval++),
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
          SheetBlock(
            label: 'From',
            child: InkWell(
              onTap: () => _pickDate(start: true),
              child: Text(Clock.day(_startsOn), style: Type.item.copyWith(color: palette.print)),
            ),
          ),
          SheetBlock(
            label: 'Until',
            child: InkWell(
              onTap: () => _pickDate(start: false),
              onLongPress: () => setState(() => _endsOn = null),
              child: Text(
                _endsOn == null ? 'No end' : Clock.day(_endsOn!),
                style: Type.item.copyWith(
                  color: _endsOn == null ? palette.faded : palette.print,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.label, this.onMinus, this.onPlus});

  final String label;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onMinus,
          icon: const AppIcon(SolarIcons.MinusCircle, size: 20),
          color: palette.print,
        ),
        Text(label, style: Type.monoBold.copyWith(color: palette.print)),
        IconButton(
          onPressed: onPlus,
          icon: const AppIcon(SolarIcons.AddCircle, size: 20),
          color: palette.print,
        ),
      ],
    );
  }
}
