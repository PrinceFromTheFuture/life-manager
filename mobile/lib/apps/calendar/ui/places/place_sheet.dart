import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';

import 'package:shopping_list/apps/calendar/data/models/place.dart';
import 'package:shopping_list/apps/calendar/data/models/place_mark.dart';
import 'package:shopping_list/apps/calendar/state/providers.dart';
import 'package:shopping_list/apps/calendar/ui/places/place_preview.dart';
import 'package:shopping_list/apps/receipts/data/location_service.dart';
import 'package:shopping_list/core/design/paper_snack.dart';
import 'package:shopping_list/core/design/stamp_ink.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/design/widgets/app_icon.dart';
import 'package:shopping_list/core/design/widgets/ink_pad.dart';

/// Name a place and pin it. Events pick from the store; they never invent one.
class PlaceSheet extends ConsumerStatefulWidget {
  const PlaceSheet({super.key, this.existing});

  final Place? existing;

  static Future<int?> open(BuildContext context, {Place? existing}) {
    return Navigator.of(context).push<int>(
      MaterialPageRoute<int>(
        fullscreenDialog: true,
        builder: (_) => PlaceSheet(existing: existing),
      ),
    );
  }

  @override
  ConsumerState<PlaceSheet> createState() => _PlaceSheetState();
}

class _PlaceSheetState extends ConsumerState<PlaceSheet> {
  late final TextEditingController _name;
  late final TextEditingController _search;
  late StampInk _ink;
  late PlaceMark _mark;
  double? _latitude;
  double? _longitude;
  bool _saving = false;
  bool _pinning = false;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _name = TextEditingController(text: existing?.title ?? '');
    _search = TextEditingController();
    _ink = existing?.ink ?? StampInk.teal;
    _mark = existing?.mark ?? PlaceMark.home;
    _latitude = existing?.latitude;
    _longitude = existing?.longitude;
  }

  @override
  void dispose() {
    _name.dispose();
    _search.dispose();
    super.dispose();
  }

  bool get _canSave =>
      _name.text.trim().isNotEmpty &&
      _latitude != null &&
      _longitude != null &&
      !_saving;

  Future<void> _useHere() async {
    setState(() => _pinning = true);
    final guess = await const LocationService().currentPlace();
    if (!mounted) return;
    setState(() {
      _pinning = false;
      _latitude = guess.latitude;
      _longitude = guess.longitude;
    });
    if (guess.latitude == null) {
      showPaperSnack(context, message: 'Could not read where you are.');
    }
  }

  Future<void> _searchPlace() async {
    final query = _search.text.trim();
    if (query.isEmpty) return;
    setState(() => _pinning = true);
    try {
      final found = await locationFromAddress(query);
      if (!mounted) return;
      if (found.isEmpty) {
        setState(() => _pinning = false);
        showPaperSnack(context, message: 'Nothing matched that search.');
        return;
      }
      setState(() {
        _latitude = found.first.latitude;
        _longitude = found.first.longitude;
        _pinning = false;
      });
    } on Exception {
      if (!mounted) return;
      setState(() => _pinning = false);
      showPaperSnack(context, message: 'The map could not find that.');
    }
  }

  Future<void> _save() async {
    final title = _name.text.trim();
    final lat = _latitude;
    final lng = _longitude;
    if (title.isEmpty || lat == null || lng == null || _saving) return;
    setState(() => _saving = true);
    final controller = ref.read(calendarControllerProvider);
    if (_editing) {
      await controller.updatePlace(
        widget.existing!.copyWith(
          title: title,
          iconId: _mark.id,
          inkId: _ink.id,
          latitude: lat,
          longitude: lng,
        ),
      );
      if (mounted) Navigator.of(context).pop(widget.existing!.id);
    } else {
      final created = await controller.addPlace(
        title: title,
        latitude: lat,
        longitude: lng,
        inkId: _ink.id,
        iconId: _mark.id,
      );
      if (mounted) Navigator.of(context).pop(created.id);
    }
  }

  Future<void> _delete() async {
    final id = widget.existing?.id;
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        final palette = context.thermal;
        return AlertDialog(
          backgroundColor: palette.paper,
          title: const Text('Remove this place?'),
          content: const Text(
            'Events that pointed here keep their time. They lose the pin.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep it'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );
    if (ok != true || !mounted) return;
    await ref.read(calendarControllerProvider).deletePlace(id);
    if (mounted) Navigator.of(context).pop(id);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    return Scaffold(
      backgroundColor: palette.paper,
      appBar: AppBar(
        title: Text(_editing ? 'Place' : 'New place'),
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
            controller: _name,
            autofocus: !_editing,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'Home, the gym, parents…',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: Space.xl),
          Text('INK', style: Type.eyebrow.copyWith(color: palette.faded)),
          const SizedBox(height: Space.sm),
          Wrap(
            spacing: Space.md,
            runSpacing: Space.md,
            children: [
              for (final ink in StampInk.all)
                StampInkPad(
                  ink: ink,
                  selected: ink.id == _ink.id,
                  showLabel: false,
                  onTap: () => setState(() => _ink = ink),
                ),
            ],
          ),
          const SizedBox(height: Space.xl),
          Text('MARK', style: Type.eyebrow.copyWith(color: palette.faded)),
          const SizedBox(height: Space.sm),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              for (final mark in PlaceMark.all)
                _IconWell(
                  mark: mark,
                  selected: mark.id == _mark.id,
                  ink: _ink,
                  onTap: () => setState(() => _mark = mark),
                ),
            ],
          ),
          const SizedBox(height: Space.xl),
          Text('PIN', style: Type.eyebrow.copyWith(color: palette.faded)),
          const SizedBox(height: Space.sm),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    hintText: 'Search a street or town',
                  ),
                  onSubmitted: (_) => _searchPlace(),
                ),
              ),
              const SizedBox(width: Space.sm),
              IconButton(
                tooltip: 'Search',
                onPressed: _pinning ? null : _searchPlace,
                icon: const AppIcon(SolarIcons.MapPointSearch),
              ),
            ],
          ),
          const SizedBox(height: Space.md),
          OutlinedButton.icon(
            onPressed: _pinning ? null : _useHere,
            icon: const AppIcon(SolarIcons.MapPoint, size: 18),
            label: Text(_pinning ? 'Pinning…' : 'Use where I am'),
          ),
          if (_latitude != null && _longitude != null) ...[
            const SizedBox(height: Space.lg),
            PlacePreview(latitude: _latitude!, longitude: _longitude!),
          ],
          if (_editing) ...[
            const SizedBox(height: Space.xxl),
            TextButton(
              onPressed: _delete,
              child: Text(
                'Remove this place',
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

class _IconWell extends StatelessWidget {
  const _IconWell({
    required this.mark,
    required this.selected,
    required this.ink,
    required this.onTap,
  });

  final PlaceMark mark;
  final bool selected;
  final StampInk ink;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    final fill = ink.of(Theme.of(context).brightness);
    return Semantics(
      button: true,
      selected: selected,
      label: mark.label,
      child: Material(
        color: selected ? fill : palette.paperShade,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.key,
          side: BorderSide(
            color: selected ? palette.print : Colors.transparent,
            width: 2,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: Radii.key,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: AppIcon(
                mark.icon,
                size: 22,
                color: selected ? palette.paper : palette.print,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
