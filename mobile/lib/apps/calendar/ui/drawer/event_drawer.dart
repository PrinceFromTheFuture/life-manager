import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shopping_list/apps/calendar/data/clock.dart';
import 'package:shopping_list/apps/calendar/data/expand/days.dart';
import 'package:shopping_list/apps/calendar/data/models/place.dart';
import 'package:shopping_list/apps/calendar/data/models/series.dart';
import 'package:shopping_list/apps/calendar/data/models/ticket.dart';
import 'package:shopping_list/apps/calendar/state/providers.dart';
import 'package:shopping_list/apps/calendar/ui/drawer/drawer_parts.dart';
import 'package:shopping_list/apps/calendar/ui/drawer/event_detail_view.dart';
import 'package:shopping_list/apps/calendar/ui/drawer/event_form_view.dart';
import 'package:shopping_list/apps/calendar/ui/drawer/event_session.dart';
import 'package:shopping_list/apps/calendar/ui/drawer/ink_view.dart';
import 'package:shopping_list/apps/calendar/ui/drawer/place_form_view.dart';
import 'package:shopping_list/apps/calendar/ui/drawer/place_view.dart';
import 'package:shopping_list/apps/calendar/ui/drawer/repeat_view.dart';
import 'package:shopping_list/apps/calendar/ui/drawer/time_picker_view.dart';
import 'package:shopping_list/apps/calendar/ui/night.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/design/widgets/app_icon.dart';
import 'package:shopping_list/core/design/widgets/multi_view_drawer.dart';

const double _pickerHeight = 0.82;

/// Open an event: its detail when [ticket] is given, else a new one at
/// [startsAt]. Completes when the drawer has closed.
Future<void> showEventDrawer(
  BuildContext context, {
  Ticket? ticket,
  DateTime? startsAt,
  int duration = 60,
}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final controller = container.read(calendarControllerProvider);
  Series? series;
  if (ticket?.seriesId != null) {
    final all = await container.read(seriesProvider.future);
    series = all.where((s) => s.id == ticket!.seriesId).firstOrNull;
  }
  if (!context.mounted) return;

  final session = ticket == null
      ? EventSession.create(
          host: context,
          controller: controller,
          startsAt: startsAt ?? _nextSlot(),
          duration: duration,
        )
      : EventSession.edit(
          host: context,
          controller: controller,
          ticket: ticket,
          series: series,
        );

  await showMultiViewDrawer<void>(
    context: context,
    initial: ticket == null ? 'form' : 'detail',
    views: _sessionViews(() => session),
  );
}

/// The routines list, and each routine's form.
Future<void> showRoutinesDrawer(BuildContext context) {
  final container = ProviderScope.containerOf(context, listen: false);
  final controller = container.read(calendarControllerProvider);
  late EventSession session;

  return showMultiViewDrawer<void>(
    context: context,
    initial: 'list',
    views: {
      'list': DrawerView(
        builder: (inner) => _RoutinesView(
          onOpen: (series) {
            session = EventSession.routine(host: context, controller: controller, series: series);
            MultiViewDrawer.of(inner).push('form');
          },
          onNew: () {
            final start = _nextSlot();
            session = EventSession.create(host: context, controller: controller, startsAt: start)
              ..repeat = const RepeatRule().withFreq(RepeatFreq.weekly, start);
            MultiViewDrawer.of(inner).push('form');
          },
        ),
      ),
      ..._sessionViews(
        () => session,
        onDone: (inner) => MultiViewDrawer.of(inner).popTo('list'),
      ),
    },
  );
}

/// Every place, to add, rename, re-pin or remove.
Future<void> showPlacesDrawer(BuildContext context) {
  Place? editing;
  return showMultiViewDrawer<void>(
    context: context,
    initial: 'list',
    views: {
      'list': DrawerView(
        builder: (inner) => PlaceView(
          title: 'Places',
          onEdit: (place) {
            editing = place;
            MultiViewDrawer.of(inner).push('form');
          },
          onNew: () {
            editing = null;
            MultiViewDrawer.of(inner).push('form');
          },
        ),
      ),
      'form': DrawerView(
        builder: (_) => PlaceFormView(
          existing: editing,
          onSaved: (inner, _) => MultiViewDrawer.of(inner).pop(),
          onDeleted: (inner, _) => MultiViewDrawer.of(inner).pop(),
        ),
      ),
    },
  );
}

DateTime _nextSlot() {
  final now = DateTime.now();
  final minutes = (Days.minutesOf(now) ~/ 30 + 1) * 30;
  return Days.atMinutes(now, minutes.clamp(0, 24 * 60 - 60));
}

Map<String, DrawerView> _sessionViews(
  EventSession Function() session, {
  void Function(BuildContext context)? onDone,
}) {
  Place? editing;
  return {
    'detail': DrawerView(builder: (_) => EventDetailView(session: session())),
    'form': DrawerView(
      builder: (_) => EventFormView(session: session(), onDone: onDone),
    ),
    'scope': DrawerView(builder: (_) => ScopeView(session: session())),
    'time': DrawerView(
      heightFactor: _pickerHeight,
      builder: (inner) {
        final s = session();
        return TimePickerView(
          start: s.startsAt,
          duration: s.duration,
          excludeKey: s.ticket?.key,
          label: s.title,
          onConfirm: (start, duration) {
            s.update((d) {
              d.startsAt = start;
              d.duration = duration;
            });
            MultiViewDrawer.of(inner).pop();
          },
        );
      },
    ),
    'move': DrawerView(
      heightFactor: _pickerHeight,
      builder: (inner) {
        final s = session();
        return TimePickerView(
          title: 'Move',
          confirmLabel: 'Move',
          start: s.startsAt,
          duration: s.duration,
          excludeKey: s.ticket?.key,
          label: s.title,
          onConfirm: (start, duration) {
            MultiViewDrawer.of(inner).close();
            s.move(start, duration);
          },
        );
      },
    ),
    'repeat': DrawerView(builder: (_) => RepeatView(session: session())),
    'ink': DrawerView(
      builder: (_) {
        final s = session();
        return InkView(
          listenable: s,
          ink: () => s.inkId,
          mark: () => s.iconId,
          onInk: (id) => s.update((d) => d.inkId = id),
          onMark: (id) => s.update((d) => d.iconId = id),
        );
      },
    ),
    'place': DrawerView(
      builder: (inner) {
        final s = session();
        return PlaceView(
          selectedId: s.locationId,
          onPick: (place) {
            s.update((d) => d.locationId = place?.id);
            MultiViewDrawer.of(inner).pop();
          },
          onEdit: (place) {
            editing = place;
            MultiViewDrawer.of(inner).push('placeForm');
          },
          onNew: () {
            editing = null;
            MultiViewDrawer.of(inner).push('placeForm');
          },
        );
      },
    ),
    'placeForm': DrawerView(
      builder: (_) {
        final s = session();
        return PlaceFormView(
          existing: editing,
          onSaved: (inner, id) {
            s.update((d) => d.locationId = id);
            MultiViewDrawer.of(inner).popTo('form');
          },
          onDeleted: (inner, id) {
            if (s.locationId == id) s.update((d) => d.locationId = null);
            MultiViewDrawer.of(inner).pop();
          },
        );
      },
    ),
  };
}

class _RoutinesView extends ConsumerWidget {
  const _RoutinesView({required this.onOpen, required this.onNew});

  final ValueChanged<Series> onOpen;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final series = ref.watch(seriesProvider).valueOrNull ?? const <Series>[];
    final places = {
      for (final place in ref.watch(placesProvider).valueOrNull ?? const <Place>[]) place.id: place,
    };
    final controller = ref.read(calendarControllerProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const DrawerViewHeader(title: 'Routines'),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: Space.lg),
            child: series.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: Space.xl),
                    child: Column(
                      children: [
                        const AppIcon(SolarIcons.Repeat, size: 34, color: Night.mist),
                        const SizedBox(height: Space.md),
                        Text('No routines yet', style: Type.itemLarge.copyWith(color: Night.bone)),
                        const SizedBox(height: 4),
                        Text(
                          'The gym on Mondays, a shift every other week.\nWrite it once; the week fills itself.',
                          textAlign: TextAlign.center,
                          style: Type.caption.copyWith(color: Night.mist),
                        ),
                      ],
                    ),
                  )
                : DrawerGroup(
                    children: [
                      for (final s in series)
                        _RoutineRow(
                          series: s,
                          place: places[s.locationId],
                          onTap: () => onOpen(s),
                          onToggle: (on) => controller.setSeriesActive(s.id!, active: on),
                        ),
                    ],
                  ),
          ),
        ),
        DrawerFooter(
          children: [
            DrawerSecondaryButton(label: 'New routine', icon: SolarIcons.AddCircle, onTap: onNew),
          ],
        ),
      ],
    );
  }
}

class _RoutineRow extends StatelessWidget {
  const _RoutineRow({
    required this.series,
    required this.place,
    required this.onTap,
    required this.onToggle,
  });

  final Series series;
  final Place? place;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final on = series.active;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.md + 2, Space.md, Space.sm, Space.md),
          child: Row(
            children: [
              AppIcon(
                place?.mark.icon ?? SolarIcons.Repeat,
                size: 22,
                color: on ? (place?.ink.dark ?? Night.bone) : Night.mist,
              ),
              const SizedBox(width: Space.md + 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      series.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Type.item.copyWith(color: on ? Night.bone : Night.mist),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        Clock.seriesRule(series),
                        if (place != null) place!.title,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Type.caption.copyWith(color: Night.mist),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: on,
                activeThumbColor: Night.ink,
                activeTrackColor: Night.bone,
                inactiveThumbColor: Night.mist,
                inactiveTrackColor: Night.ground,
                onChanged: (value) {
                  HapticFeedback.selectionClick();
                  onToggle(value);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
