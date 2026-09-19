import 'package:flutter/material.dart';

import 'package:shopping_list/apps/calendar/data/clock.dart';
import 'package:shopping_list/apps/calendar/data/models/place.dart';
import 'package:shopping_list/apps/calendar/data/models/place_mark.dart';
import 'package:shopping_list/apps/calendar/data/models/ticket.dart';
import 'package:shopping_list/core/design/stamp_ink.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/design/widgets/app_icon.dart';

/// A blotter ticket. The whole plate lifts; the ink is the fill.
class TicketCard extends StatelessWidget {
  const TicketCard({
    super.key,
    required this.ticket,
    required this.place,
    this.lifted = false,
    this.compact = false,
    this.continuation = false,
    this.onTap,
    this.onLongPressStart,
  });

  final Ticket ticket;
  final Place? place;
  final bool lifted;
  final bool compact;
  final bool continuation;
  final VoidCallback? onTap;
  final GestureLongPressStartCallback? onLongPressStart;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    final brightness = Theme.of(context).brightness;
    final light = brightness == Brightness.light;
    final eventInk = ticket.inkId == null ? null : StampInk.byId(ticket.inkId);
    final stamp = (eventInk ?? place?.ink)?.of(brightness) ?? palette.carbon;
    final onInk = light ? palette.paper : palette.print;
    final mark = ticket.iconId != null
        ? PlaceMark.byId(ticket.iconId)
        : place?.mark;
    final reduced = MediaQuery.disableAnimationsOf(context);
    final scale = lifted && !reduced ? 1.04 : 1.0;

    return AnimatedScale(
      scale: scale,
      duration: reduced ? Duration.zero : Motion.quick,
      child: Material(
        color: stamp,
        elevation: lifted ? 6 : 0,
        shadowColor: palette.print.withValues(alpha: 0.18),
        borderRadius: Radii.key,
        clipBehavior: Clip.antiAlias,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          onLongPressStart: onLongPressStart,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 6 : Space.sm,
              compact ? 4 : 6,
              compact ? 6 : Space.sm,
              compact ? 4 : 6,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        continuation ? '↩ ${ticket.title}' : ticket.title,
                        style: Type.item.copyWith(
                          color: onInk,
                          fontFamily: Fonts.display,
                          fontWeight: FontWeight.w700,
                          fontSize: compact ? 12 : 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (!compact)
                        Text(
                          Clock.span(ticket.startsAt, ticket.durationMinutes),
                          style: Type.mono.copyWith(
                            color: onInk.withValues(alpha: 0.78),
                            fontSize: 11,
                          ),
                        ),
                      if (!compact && (ticket.note ?? '').isNotEmpty)
                        Text(
                          ticket.note!,
                          style: Type.caption.copyWith(
                            color: onInk.withValues(alpha: 0.72),
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                if (!compact && mark != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: AppIcon(mark.icon, size: 14, color: onInk),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
