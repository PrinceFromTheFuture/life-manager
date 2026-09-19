import 'package:flutter/material.dart';

import 'package:shopping_list/core/design/tokens.dart';

/// The app's signature: checking an item off burns it into the paper.
///
/// Rather than the usual strikethrough-and-fade, the row darkens the way
/// thermal paper actually does — browning through [ThermalPalette.scorch]
/// before it goes to full print black — and the darkening *sweeps across the
/// row*, the way a receipt printer's head travels. The ink inverts partway
/// through so the text stays readable the whole time.
///
/// Everything else in this app is deliberately quiet so that this one moment
/// can carry it.
class ThermalSurface extends StatelessWidget {
  const ThermalSurface({
    super.key,
    required this.burned,
    required this.builder,
    this.duration = Motion.burn,
  });

  /// Target state. Animating between the two is what produces the burn.
  final bool burned;

  /// Receives the row's current background and the ink colour that reads
  /// against it. Both are needed: anything knocked *out* of the ink (a tick
  /// inside a filled box) has to be painted in the background colour, and
  /// mid-burn that is neither paper nor print.
  final Widget Function(BuildContext context, Color background, Color ink)
      builder;

  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;

    // Reduced motion gets the end state immediately — the information the burn
    // conveys is carried by its final colour, not by the transition, so
    // nothing is lost by skipping it.
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: burned ? 1 : 0),
      duration: reduceMotion ? Duration.zero : duration,
      curve: Motion.heat,
      builder: (context, t, child) {
        final settled = palette.burnGround(t);
        final cool = palette.paper;

        // Three zones travelling left to right: paper still untouched ahead of
        // the head, a hot glow directly under it, and cooled scorch behind.
        // The glow is what makes this read as something being printed rather
        // than a rectangle changing colour.
        const band = 0.09;
        final lead = (t * (1 + band * 2)) - band;

        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [settled, settled, palette.scorch, cool, cool],
              stops: [
                0,
                (lead - band).clamp(0.0, 1.0),
                lead.clamp(0.0, 1.0),
                (lead + band).clamp(0.0, 1.0),
                1,
              ],
            ),
          ),
          child: builder(context, settled, palette.burnInk(t)),
        );
      },
    );
  }
}
