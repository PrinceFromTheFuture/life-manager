import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:shopping_list/apps/calendar/data/clock.dart';
import 'package:shopping_list/apps/calendar/data/models/place.dart';
import 'package:shopping_list/apps/calendar/state/providers.dart';
import 'package:shopping_list/apps/calendar/ui/drawer/drawer_parts.dart';
import 'package:shopping_list/apps/calendar/ui/drawer/event_session.dart';
import 'package:shopping_list/apps/calendar/ui/night.dart';
import 'package:shopping_list/core/design/stamp_ink.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/design/widgets/app_icon.dart';
import 'package:shopping_list/core/design/widgets/multi_view_drawer.dart';

/// Name it, and everything else is one row away.
///
/// The title is the only field typed on this view; time, repeat, place and
/// stamp are rows that open their own views and come back with an answer.
class EventFormView extends ConsumerStatefulWidget {
  const EventFormView({super.key, required this.session, this.onDone});

  final EventSession session;

  /// After a save or delete. Closes the drawer unless given.
  final void Function(BuildContext context)? onDone;

  @override
  ConsumerState<EventFormView> createState() => _EventFormViewState();
}

class _EventFormViewState extends ConsumerState<EventFormView> {
  late final TextEditingController _title =
      TextEditingController(text: widget.session.title);
  late final TextEditingController _note =
      TextEditingController(text: widget.session.note);

  bool _confirmDelete = false;
  Timer? _disarm;

  EventSession get _session => widget.session;

  @override
  void initState() {
    super.initState();
    _title.addListener(() => _session.update((d) => d.title = _title.text));
    _note.addListener(() => _session.note = _note.text);
  }

  @override
  void dispose() {
    _disarm?.cancel();
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  void _done() {
    if (!mounted) return;
    final onDone = widget.onDone;
    if (onDone != null) {
      onDone(context);
    } else {
      MultiViewDrawer.of(context).close();
    }
  }

  Future<void> _save() async {
    final drawer = MultiViewDrawer.of(context);
    FocusScope.of(context).unfocus();
    if (_session.needsScope) {
      drawer.push('scope');
      return;
    }
    await _session.save();
    _done();
  }

  Future<void> _deleteRoutine() async {
    if (!_confirmDelete) {
      unawaited(HapticFeedback.mediumImpact());
      setState(() => _confirmDelete = true);
      _disarm?.cancel();
      _disarm = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _confirmDelete = false);
      });
      return;
    }
    await _session.deleteRoutine();
    _done();
  }

  String get _heading {
    if (_session.isRoutine) return 'Routine';
    if (_session.isNew) return 'New event';
    return 'Edit';
  }

  @override
  Widget build(BuildContext context) {
    final drawer = MultiViewDrawer.of(context);
    final places = ref.watch(placesProvider).valueOrNull ?? const <Place>[];

    return ListenableBuilder(
      listenable: _session,
      builder: (context, _) {
        final s = _session;
        final place = places.where((p) => p.id == s.locationId).firstOrNull;
        final stamp = s.inkId == null ? null : StampInk.byId(s.inkId);
        final when = s.isRoutine
            ? Clock.span(s.startsAt, s.duration)
            : '${DateFormat('EEE d MMM').format(s.startsAt)} · ${Clock.span(s.startsAt, s.duration)}';

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DrawerViewHeader(title: _heading),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: Space.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _title,
                      autofocus: s.isNew,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => FocusScope.of(context).unfocus(),
                      style: Type.display.copyWith(fontSize: 24, color: Night.bone),
                      decoration: InputDecoration(
                        hintText: 'What\'s happening?',
                        hintStyle: Type.display.copyWith(fontSize: 24, color: Night.mist),
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: Space.sm),
                      ),
                    ),
                    const SizedBox(height: Space.md),
                    DrawerGroup(
                      children: [
                        DrawerRow(
                          icon: SolarIcons.ClockCircle,
                          label: s.isRoutine ? 'Time' : 'When',
                          value: when,
                          valueColor: Night.bone,
                          onTap: () => drawer.push('time'),
                        ),
                        DrawerRow(
                          icon: SolarIcons.Repeat,
                          label: 'Repeat',
                          value: s.repeat.describe(),
                          valueColor: s.repeat.repeats ? Night.bone : null,
                          onTap: () => drawer.push('repeat'),
                        ),
                        DrawerRow(
                          icon: place?.mark.icon ?? SolarIcons.MapPoint,
                          iconColor: place?.ink.dark,
                          label: 'Place',
                          value: place?.title ?? 'None',
                          valueColor: place == null ? null : Night.bone,
                          onTap: () => drawer.push('place'),
                        ),
                        if (s.carriesStamp)
                          DrawerRow(
                            icon: SolarIcons.Palette,
                            iconColor: stamp?.dark,
                            label: 'Stamp',
                            value: stamp?.label ?? (place == null ? 'None' : 'From place'),
                            valueColor: stamp == null ? null : Night.bone,
                            onTap: () => drawer.push('ink'),
                          ),
                      ],
                    ),
                    if (s.carriesStamp) ...[
                      const SizedBox(height: Space.md),
                      TextField(
                        controller: _note,
                        minLines: 1,
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                        style: Type.item.copyWith(color: Night.bone),
                        decoration: const InputDecoration(hintText: 'Note'),
                      ),
                    ],
                    if (s.isOccurrence) ...[
                      const SizedBox(height: Space.md),
                      Row(
                        children: [
                          const AppIcon(SolarIcons.InfoCircle, size: 16, color: Night.mist),
                          const SizedBox(width: Space.sm),
                          Expanded(
                            child: Text(
                              s.ticket!.overridden
                                  ? 'This time was already changed. The routine is not.'
                                  : 'Part of a routine. Saving asks whether it is this time or every time.',
                              style: Type.caption.copyWith(color: Night.mist),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            DrawerFooter(
              children: [
                if (s.isRoutine)
                  DrawerSecondaryButton(
                    label: _confirmDelete ? 'Tap to delete' : 'Delete',
                    icon: SolarIcons.TrashBinMinimalistic,
                    color: Night.danger,
                    onTap: _deleteRoutine,
                  ),
                DrawerPrimaryButton(
                  label: s.isNew ? (s.repeat.repeats ? 'Add routine' : 'Add') : 'Save',
                  busy: s.saving,
                  onTap: s.canSave ? _save : null,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// This time or every time, for an edit to one occurrence of a routine.
class ScopeView extends StatelessWidget {
  const ScopeView({super.key, required this.session});

  final EventSession session;

  Future<void> _pick(BuildContext context, EditScope scope) async {
    final drawer = MultiViewDrawer.of(context);
    await session.save(scope: scope);
    drawer.close();
  }

  @override
  Widget build(BuildContext context) {
    final ticket = session.ticket!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const DrawerViewHeader(title: 'Save for'),
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.lg),
          child: Column(
            children: [
              _ScopeOption(
                icon: SolarIcons.CalendarMark,
                title: 'This time only',
                body: '${DateFormat('EEEE d MMMM').format(ticket.originalStart)}. '
                    'The routine stays as it is.',
                onTap: () => _pick(context, EditScope.thisTime),
              ),
              const SizedBox(height: Space.sm),
              _ScopeOption(
                icon: SolarIcons.Repeat,
                title: 'All events',
                body: '${session.repeat.describe()}, from now on.',
                onTap: () => _pick(context, EditScope.all),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ScopeOption extends StatelessWidget {
  const _ScopeOption({
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
  });

  final SolarIconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Night.well,
      borderRadius: const BorderRadius.all(Radius.circular(18)),
      child: InkWell(
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Space.lg),
          child: Row(
            children: [
              AppIcon(icon, size: 26, color: Night.bone),
              const SizedBox(width: Space.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Type.itemLarge.copyWith(color: Night.bone)),
                    const SizedBox(height: 2),
                    Text(body, style: Type.caption.copyWith(color: Night.mist)),
                  ],
                ),
              ),
              const AppIcon(SolarIcons.AltArrowRight, size: 18, color: Night.mist),
            ],
          ),
        ),
      ),
    );
  }
}
