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
import 'package:shopping_list/apps/calendar/ui/navigate_open.dart';
import 'package:shopping_list/apps/calendar/ui/night.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/design/widgets/app_icon.dart';
import 'package:shopping_list/core/design/widgets/multi_view_drawer.dart';

/// An event at a glance, with what you would do to it next.
class EventDetailView extends ConsumerWidget {
  const EventDetailView({super.key, required this.session});

  final EventSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drawer = MultiViewDrawer.of(context);
    final ticket = session.ticket!;
    final places = ref.watch(placesProvider).valueOrNull ?? const <Place>[];
    final place = places.where((p) => p.id == ticket.locationId).firstOrNull;
    final ink = Night.inkOf(ticket, place);
    final hours = ticket.durationMinutes ~/ 60;
    final minutes = ticket.durationMinutes % 60;
    final length = hours == 0 ? '$minutes min' : (minutes == 0 ? '$hours h' : '$hours h $minutes min');
    final note = ticket.note?.trim();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DrawerViewHeader(
          title: ticket.title,
          trailing: NightRoundButton(
            icon: SolarIcons.Pen,
            label: 'Edit',
            onTap: () => drawer.push('form'),
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        width: 4,
                        decoration: BoxDecoration(
                          color: ink,
                          borderRadius: const BorderRadius.all(Radius.circular(2)),
                        ),
                      ),
                      const SizedBox(width: Space.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat('EEEE d MMMM').format(ticket.startsAt),
                              style: Type.itemLarge.copyWith(color: Night.bone),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${Clock.span(ticket.startsAt, ticket.durationMinutes)} · $length',
                              style: Type.mono.copyWith(color: Night.mist),
                            ),
                            if (ticket.fromRegistry) ...[
                              const SizedBox(height: Space.sm),
                              Row(
                                children: [
                                  const AppIcon(SolarIcons.Repeat, size: 14, color: Night.mist),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      session.repeat.describe(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Type.caption.copyWith(color: Night.mist),
                                    ),
                                  ),
                                  if (ticket.overridden) ...[
                                    const SizedBox(width: Space.sm),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: Night.caution.withValues(alpha: 0.14),
                                        borderRadius: const BorderRadius.all(Radius.circular(6)),
                                      ),
                                      child: Text(
                                        'Changed this time',
                                        style: Type.caption.copyWith(
                                          fontSize: 11,
                                          color: Night.caution,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (place != null) ...[
                  const SizedBox(height: Space.lg),
                  DrawerGroup(
                    children: [
                      DrawerRow(
                        icon: place.mark.icon,
                        iconColor: place.ink.dark,
                        label: place.title,
                        value: 'Navigate',
                        valueColor: Night.bone,
                        trailing: const AppIcon(SolarIcons.Routing, size: 18, color: Night.bone),
                        chevron: false,
                        onTap: () => NavigateOpen.to(place),
                      ),
                    ],
                  ),
                ],
                if (note != null && note.isNotEmpty) ...[
                  const SizedBox(height: Space.md),
                  Container(
                    padding: const EdgeInsets.all(Space.md + 2),
                    decoration: const BoxDecoration(
                      color: Night.well,
                      borderRadius: BorderRadius.all(Radius.circular(18)),
                    ),
                    child: Text(note, style: Type.body.copyWith(color: Night.bone)),
                  ),
                ],
                const SizedBox(height: Space.lg),
                Row(
                  children: [
                    Expanded(
                      child: _Action(
                        icon: SolarIcons.ClockCircle,
                        label: 'Move',
                        onTap: () => drawer.push('move'),
                      ),
                    ),
                    const SizedBox(width: Space.sm),
                    Expanded(
                      child: _Action(
                        icon: SolarIcons.Pen,
                        label: 'Edit',
                        onTap: () => drawer.push('form'),
                      ),
                    ),
                    const SizedBox(width: Space.sm),
                    Expanded(
                      child: _Action(
                        icon: ticket.fromRegistry ? SolarIcons.SkipNext : SolarIcons.TrashBinMinimalistic,
                        label: ticket.fromRegistry ? 'Skip this time' : 'Delete',
                        color: Night.danger,
                        onTap: () async {
                          unawaited(HapticFeedback.mediumImpact());
                          drawer.close();
                          await session.remove();
                        },
                      ),
                    ),
                  ],
                ),
                if (ticket.overridden) ...[
                  const SizedBox(height: Space.sm),
                  DrawerSecondaryButton(
                    label: 'Back to the routine',
                    icon: SolarIcons.Restart,
                    onTap: () async {
                      drawer.close();
                      await session.restore();
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final SolarIconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ink = color ?? Night.bone;
    return Material(
      color: Night.well,
      borderRadius: const BorderRadius.all(Radius.circular(18)),
      child: InkWell(
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: SizedBox(
          height: 78,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppIcon(icon, size: 24, color: ink),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Type.caption.copyWith(color: ink),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
