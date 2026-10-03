import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutty_solar_icons/solar_icons_flutter.dart';

import 'package:shopping_list/apps/calendar/data/clock.dart';
import 'package:shopping_list/apps/calendar/data/models/place.dart';
import 'package:shopping_list/apps/calendar/data/models/place_mark.dart';
import 'package:shopping_list/apps/calendar/data/models/ticket.dart';
import 'package:shopping_list/apps/calendar/ui/grid/grid_metrics.dart';
import 'package:shopping_list/apps/calendar/ui/grid/lift_recognizer.dart';
import 'package:shopping_list/apps/calendar/ui/night.dart';
import 'package:shopping_list/core/design/theme.dart';

/// Where a held card was grabbed. The bottom edge stretches it; anywhere else
/// carries it.
class LiftStart {
  const LiftStart({
    required this.ticket,
    required this.global,
    required this.resize,
  });

  final Ticket ticket;
  final Offset global;
  final bool resize;
}

/// One event on the grid.
///
/// Tinted in its stamp ink with a solid edge. What it prints depends on how
/// tall it is: the title always, the place from 36 px, the time from 56 px.
class EventCard extends StatelessWidget {
  const EventCard({
    super.key,
    required this.ticket,
    required this.place,
    required this.height,
    this.compact = false,
    this.past = false,
    this.continuation = false,
    this.lifted = false,
    this.animateIn = true,
  });

  final Ticket ticket;
  final Place? place;
  final double height;
  final bool compact;
  final bool past;
  final bool continuation;
  final bool lifted;
  final bool animateIn;

  static const double placeTier = 36;
  static const double timeTier = 56;

  @override
  Widget build(BuildContext context) {
    final ink = Night.inkOf(ticket, place);
    final mark = ticket.iconId != null
        ? PlaceMark.byId(ticket.iconId)
        : place?.mark;
    final showPlace = height >= placeTier && !compact && place != null;
    final showTime = height >= timeTier && !compact;
    final titleLines = height >= 72 && !compact ? 2 : 1;

    final card = DecoratedBox(
      decoration: BoxDecoration(
        color: Night.cardFill(ink),
        borderRadius: BorderRadius.circular(compact ? 4 : 7),
        boxShadow: lifted
            ? const [
                BoxShadow(
                  color: Color(0x99000000),
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(compact ? 4 : 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: compact ? 2 : 3, color: Night.cardEdge(ink)),
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  compact ? 3 : 6,
                  height < 28 ? 1 : (compact ? 3 : 5),
                  compact ? 2 : 4,
                  1,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showTime)
                      Text(
                        Clock.span(ticket.startsAt, ticket.durationMinutes),
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        softWrap: false,
                        style: Type.mono.copyWith(
                          color: ink,
                          fontSize: 10.5,
                          height: 1.25,
                        ),
                      ),
                    Text(
                      continuation ? '↳ ${ticket.title}' : ticket.title,
                      maxLines: titleLines,
                      overflow: TextOverflow.ellipsis,
                      style: Type.body.copyWith(
                        color: Night.bone,
                        fontSize: compact ? 11 : 13,
                        height: 1.2,
                        fontWeight: FontWeight.w600,
                        fontVariations: const [FontVariation('wght', 600)],
                      ),
                    ),
                    if (showPlace)
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Row(
                          children: [
                            if (mark != null) ...[
                              SolarIcon(
                                mark.icon,
                                weight: SolarIconWeight.linear,
                                size: 11,
                                color: Night.mist,
                              ),
                              const SizedBox(width: 3),
                            ],
                            Expanded(
                              child: Text(
                                place!.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Type.caption.copyWith(
                                  color: Night.mist,
                                  fontSize: 11,
                                  height: 1.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    final faded = Opacity(opacity: past && !lifted ? 0.55 : 1, child: card);
    if (!animateIn || MediaQuery.disableAnimationsOf(context)) return faded;
    return faded
        .animate()
        .fadeIn(duration: GridMetrics.cardMount, curve: Curves.easeOut)
        .scaleXY(
          begin: 0.95,
          end: 1,
          duration: GridMetrics.cardMount,
          curve: Curves.easeOut,
        );
  }
}

/// Tap to open, hold to lift. The two never fight: letting go before the
/// press delay is a tap; holding past it is a lift and the scroll views lose
/// the pointer.
class EventTarget extends StatelessWidget {
  const EventTarget({
    super.key,
    required this.ticket,
    required this.onTap,
    required this.onLift,
    required this.onMove,
    required this.onDrop,
    required this.onCancel,
    required this.child,
  });

  final Ticket ticket;
  final VoidCallback onTap;
  final ValueChanged<LiftStart> onLift;
  final ValueChanged<Offset> onMove;
  final VoidCallback onDrop;
  final VoidCallback onCancel;
  final Widget child;

  /// Grabbing this close to the bottom stretches the event instead.
  static const double resizeZone = 14;

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      gestures: {
        TapGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
          TapGestureRecognizer.new,
          (tap) => tap.onTap = onTap,
        ),
        LiftRecognizer: GestureRecognizerFactoryWithHandlers<LiftRecognizer>(
          LiftRecognizer.new,
          (lift) => lift
            ..onLift = (details) {
              final box = context.findRenderObject() as RenderBox?;
              final local = box?.globalToLocal(details.globalPosition);
              final resize = box != null &&
                  local != null &&
                  box.size.height >= 30 &&
                  local.dy >= box.size.height - resizeZone;
              onLift(
                LiftStart(
                  ticket: ticket,
                  global: details.globalPosition,
                  resize: resize,
                ),
              );
            }
            ..onMove = ((details) => onMove(details.globalPosition))
            ..onDrop = ((_) => onDrop())
            ..onCancel = onCancel,
        ),
      },
      child: child,
    );
  }
}
