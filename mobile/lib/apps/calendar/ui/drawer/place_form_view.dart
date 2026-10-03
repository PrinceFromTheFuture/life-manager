import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';

import 'package:shopping_list/apps/calendar/data/models/place.dart';
import 'package:shopping_list/apps/calendar/data/models/place_mark.dart';
import 'package:shopping_list/apps/calendar/state/providers.dart';
import 'package:shopping_list/apps/calendar/ui/drawer/drawer_parts.dart';
import 'package:shopping_list/apps/calendar/ui/drawer/ink_view.dart';
import 'package:shopping_list/apps/calendar/ui/night.dart';
import 'package:shopping_list/apps/calendar/ui/places/place_preview.dart';
import 'package:shopping_list/apps/receipts/data/location_service.dart';
import 'package:shopping_list/core/design/stamp_ink.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/design/widgets/app_icon.dart';
import 'package:shopping_list/core/design/widgets/multi_view_drawer.dart';

/// Name a place and pin it. Events pick from the store; they never invent one.
class PlaceFormView extends ConsumerStatefulWidget {
  const PlaceFormView({
    super.key,
    this.existing,
    required this.onSaved,
    this.onDeleted,
  });

  final Place? existing;
  final void Function(BuildContext context, int id) onSaved;
  final void Function(BuildContext context, int id)? onDeleted;

  @override
  ConsumerState<PlaceFormView> createState() => _PlaceFormViewState();
}

class _PlaceFormViewState extends ConsumerState<PlaceFormView> {
  late final TextEditingController _name =
      TextEditingController(text: widget.existing?.title ?? '');
  final _search = TextEditingController();
  late String _ink = widget.existing?.inkId ?? StampInk.teal.id;
  late String _mark = widget.existing?.iconId ?? PlaceMark.home.id;
  late double? _latitude = widget.existing?.latitude;
  late double? _longitude = widget.existing?.longitude;
  bool _pinning = false;
  bool _saving = false;
  bool _confirmDelete = false;
  String? _problem;
  Timer? _disarm;

  bool get _editing => widget.existing != null;

  bool get _canSave =>
      _name.text.trim().isNotEmpty && _latitude != null && _longitude != null && !_saving;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
    if (!_editing) {
      final used = (ref.read(placesProvider).valueOrNull ?? const <Place>[]);
      _ink = StampInk.next(used.map((p) => p.inkId));
      _mark = PlaceMark.next(used.map((p) => p.iconId));
    }
  }

  @override
  void dispose() {
    _disarm?.cancel();
    _name.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _useHere() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _pinning = true;
      _problem = null;
    });
    final guess = await const LocationService().currentPlace();
    if (!mounted) return;
    setState(() {
      _pinning = false;
      if (guess.latitude == null) {
        _problem = 'Could not read where you are.';
        return;
      }
      _latitude = guess.latitude;
      _longitude = guess.longitude;
    });
    if (guess.latitude != null) unawaited(HapticFeedback.lightImpact());
  }

  Future<void> _searchPlace() async {
    final query = _search.text.trim();
    if (query.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _pinning = true;
      _problem = null;
    });
    try {
      final found = await locationFromAddress(query);
      if (!mounted) return;
      setState(() {
        _pinning = false;
        if (found.isEmpty) {
          _problem = 'Nothing matched "$query".';
          return;
        }
        _latitude = found.first.latitude;
        _longitude = found.first.longitude;
        if (_name.text.trim().isEmpty) _name.text = query;
      });
      if (found.isNotEmpty) unawaited(HapticFeedback.lightImpact());
    } on Exception {
      if (!mounted) return;
      setState(() {
        _pinning = false;
        _problem = 'The map could not find that.';
      });
    }
  }

  Future<void> _save() async {
    final lat = _latitude;
    final lng = _longitude;
    final title = _name.text.trim();
    if (!_canSave || lat == null || lng == null) return;
    setState(() => _saving = true);
    final controller = ref.read(calendarControllerProvider);
    final existing = widget.existing;
    int id;
    if (existing != null) {
      await controller.updatePlace(
        existing.copyWith(
          title: title,
          iconId: _mark,
          inkId: _ink,
          latitude: lat,
          longitude: lng,
        ),
      );
      id = existing.id!;
    } else {
      final created = await controller.addPlace(
        title: title,
        latitude: lat,
        longitude: lng,
        inkId: _ink,
        iconId: _mark,
      );
      id = created.id!;
    }
    if (!mounted) return;
    widget.onSaved(context, id);
  }

  Future<void> _delete() async {
    final id = widget.existing?.id;
    if (id == null) return;
    if (!_confirmDelete) {
      unawaited(HapticFeedback.mediumImpact());
      setState(() => _confirmDelete = true);
      _disarm?.cancel();
      _disarm = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _confirmDelete = false);
      });
      return;
    }
    await ref.read(calendarControllerProvider).deletePlace(id);
    if (!mounted) return;
    if (widget.onDeleted != null) {
      widget.onDeleted!(context, id);
    } else {
      MultiViewDrawer.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ink = StampInk.byId(_ink).dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DrawerViewHeader(title: _editing ? 'Place' : 'New place'),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: Space.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _name,
                  autofocus: !_editing,
                  textCapitalization: TextCapitalization.sentences,
                  style: Type.display.copyWith(fontSize: 24, color: Night.bone),
                  decoration: InputDecoration(
                    hintText: 'Home, the gym, parents…',
                    hintStyle: Type.display.copyWith(fontSize: 24, color: Night.mist),
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: Space.sm),
                  ),
                ),
                const SizedBox(height: Space.md),
                TextField(
                  controller: _search,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _searchPlace(),
                  style: Type.item.copyWith(color: Night.bone),
                  decoration: InputDecoration(
                    hintText: 'Search a street or town',
                    prefixIcon: const Padding(
                      padding: EdgeInsets.only(left: Space.md, right: Space.sm),
                      child: AppIcon(SolarIcons.Magnifer, size: 20, color: Night.mist),
                    ),
                    prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                    suffixIcon: _pinning
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Night.mist),
                            ),
                          )
                        : IconButton(
                            onPressed: _searchPlace,
                            tooltip: 'Search',
                            icon: const AppIcon(SolarIcons.MapPointSearch, size: 20, color: Night.bone),
                          ),
                  ),
                ),
                const SizedBox(height: Space.sm),
                ClipRRect(
                  borderRadius: const BorderRadius.all(Radius.circular(18)),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _latitude != null && _longitude != null
                        ? PlacePreview(
                            key: ValueKey('$_latitude,$_longitude'),
                            latitude: _latitude!,
                            longitude: _longitude!,
                            height: 150,
                          )
                        : Container(
                            height: 96,
                            color: Night.well,
                            alignment: Alignment.center,
                            child: Text(
                              'No pin yet. Search, or use where you are.',
                              style: Type.caption.copyWith(color: Night.mist),
                            ),
                          ),
                  ),
                ),
                if (_problem != null) ...[
                  const SizedBox(height: Space.sm),
                  Text(_problem!, style: Type.caption.copyWith(color: Night.caution)),
                ],
                const SizedBox(height: Space.sm),
                DrawerSecondaryButton(
                  label: _pinning ? 'Pinning…' : 'Use where I am',
                  icon: SolarIcons.GPS,
                  onTap: _pinning ? null : _useHere,
                ),
                const DrawerLabel('Ink'),
                InkGrid(selected: _ink, onPick: (id) => setState(() => _ink = id ?? _ink)),
                const DrawerLabel('Mark'),
                MarkGrid(
                  selected: _mark,
                  ink: ink,
                  onPick: (id) => setState(() => _mark = id ?? _mark),
                ),
                const SizedBox(height: Space.sm),
              ],
            ),
          ),
        ),
        DrawerFooter(
          children: [
            if (_editing)
              DrawerSecondaryButton(
                label: _confirmDelete ? 'Tap to remove' : 'Remove',
                icon: SolarIcons.TrashBinMinimalistic,
                color: Night.danger,
                onTap: _delete,
              ),
            DrawerPrimaryButton(
              label: _editing ? 'Save' : 'Add place',
              busy: _saving,
              onTap: _canSave ? _save : null,
            ),
          ],
        ),
      ],
    );
  }
}
