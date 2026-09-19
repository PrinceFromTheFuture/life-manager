import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shopping_list/apps/calendar/calendar_app.dart';
import 'package:shopping_list/apps/calendar/data/clock.dart';
import 'package:shopping_list/apps/calendar/data/models/place.dart';
import 'package:shopping_list/apps/calendar/data/models/ticket.dart';
import 'package:shopping_list/apps/calendar/state/providers.dart';
import 'package:shopping_list/apps/calendar/ui/calendar_shell.dart';
import 'package:shopping_list/core/app/mini_app_host.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/design/widgets/app_icon.dart';
import 'package:shopping_list/core/design/widgets/perforation.dart';

/// Today's remaining tickets, under the launchers.
class TodayRail extends ConsumerWidget {
  const TodayRail({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.thermal;
    final tickets = ref.watch(todayTicketsProvider);
    final places = {
      for (final place in ref.watch(placesProvider).valueOrNull ?? const <Place>[])
        if (place.id != null) place.id!: place,
    };
    const calendar = CalendarApp();
    final ink = calendar.ink.of(Theme.of(context).brightness);

    return tickets.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (items) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const TearEdge(),
              const SizedBox(height: Space.md),
              Text('TODAY', style: Type.eyebrow.copyWith(color: palette.faded)),
              const SizedBox(height: Space.sm),
              if (items.isEmpty)
                Text(
                  'Nothing today.',
                  style: Type.caption.copyWith(color: palette.faded),
                )
              else
                SizedBox(
                  height: 72,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(width: Space.sm),
                    itemBuilder: (context, i) => _HubTicket(
                      ticket: items[i],
                      place: items[i].locationId == null
                          ? null
                          : places[items[i].locationId!],
                      ink: ink,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _HubTicket extends StatelessWidget {
  const _HubTicket({
    required this.ticket,
    required this.place,
    required this.ink,
  });

  final Ticket ticket;
  final Place? place;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    final stamp = place?.ink.of(Theme.of(context).brightness) ?? ink;

    return Material(
      color: palette.paperShade,
      borderRadius: Radii.key,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openMiniApp(
          context,
          const CalendarApp(),
          initialScreen: (_) => CalendarShell(occurredAt: ticket.startsAt),
        ),
        child: SizedBox(
          width: 168,
          child: Row(
            children: [
              Container(width: 3, color: stamp),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(Space.sm, 8, Space.sm, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        Clock.hm(ticket.startsAt),
                        style: Type.monoBold.copyWith(color: palette.print),
                      ),
                      Text(
                        ticket.title,
                        style: Type.item.copyWith(
                          color: palette.print,
                          fontFamily: Fonts.display,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              if (place != null)
                Padding(
                  padding: const EdgeInsets.only(right: Space.sm),
                  child: AppIcon(place!.mark.icon, size: 14, color: stamp),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
