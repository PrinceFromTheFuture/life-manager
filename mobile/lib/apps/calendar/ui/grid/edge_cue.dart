import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutty_solar_icons/solar_icons_flutter.dart';

import 'package:shopping_list/apps/calendar/ui/grid/grid_metrics.dart';
import 'package:shopping_list/apps/calendar/ui/night.dart';
import 'package:shopping_list/core/design/theme.dart';

/// How far past a week edge the columns are being pulled.
@immutable
class Pull {
  const Pull({required this.side, required this.distance, required this.armed});

  static const none = Pull(side: 0, distance: 0, armed: false);

  /// -1 past Sunday, +1 past Saturday, 0 at rest.
  final int side;
  final double distance;
  final bool armed;

  @override
  bool operator ==(Object other) =>
      other is Pull &&
      other.side == side &&
      other.distance == distance &&
      other.armed == armed;

  @override
  int get hashCode => Object.hash(side, distance, armed);
}

/// "Next week" beside the edge being pulled.
///
/// It fades in past [GridMetrics.pullLabel], follows the finger, and fills in
/// bone once releasing would switch the week.
class EdgeCue extends StatelessWidget {
  const EdgeCue({super.key, required this.pull, required this.label});

  final ValueListenable<Pull> pull;

  /// Label for a side: "Next week", "Previous week".
  final String Function(int side) label;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ValueListenableBuilder<Pull>(
        valueListenable: pull,
        builder: (context, pull, _) {
          if (pull.side == 0) return const SizedBox.shrink();
          final shown = ((pull.distance - GridMetrics.pullLabel) /
                  GridMetrics.pullLabel)
              .clamp(0.0, 1.0);
          if (shown == 0) return const SizedBox.shrink();
          final travel = (pull.distance * 0.5).clamp(0.0, 64.0);
          final next = pull.side > 0;
          final fill = pull.armed ? Night.bone : Night.well;
          final text = pull.armed ? Night.ink : Night.bone;

          return Align(
            alignment: next ? Alignment.centerRight : Alignment.centerLeft,
            child: Transform.translate(
              offset: Offset(next ? -travel + 8 : travel - 8, 0),
              child: Opacity(
                opacity: shown,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: fill,
                    borderRadius: const BorderRadius.all(Radius.circular(999)),
                    boxShadow: const [
                      BoxShadow(color: Color(0x66000000), blurRadius: 12),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!next) ...[
                        SolarIcon(
                          SolarIcons.AltArrowLeft,
                          weight: SolarIconWeight.linear,
                          size: 14,
                          color: text,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        label(pull.side),
                        style: Type.button.copyWith(fontSize: 13, color: text),
                      ),
                      if (next) ...[
                        const SizedBox(width: 4),
                        SolarIcon(
                          SolarIcons.AltArrowRight,
                          weight: SolarIconWeight.linear,
                          size: 14,
                          color: text,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
