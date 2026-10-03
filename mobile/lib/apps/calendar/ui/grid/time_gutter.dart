import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:shopping_list/apps/calendar/data/clock.dart';
import 'package:shopping_list/apps/calendar/ui/grid/grid_metrics.dart';
import 'package:shopping_list/apps/calendar/ui/night.dart';
import 'package:shopping_list/core/design/theme.dart';

/// A time printed in the gutter on a pill: now, or where a held event is.
class GutterPill {
  const GutterPill({required this.minutes, required this.strong});

  final int minutes;

  /// Bone fill. The now pill is quiet unless nothing is being dragged.
  final bool strong;
}

/// Hours down the left, pinned while the columns scroll sideways.
///
/// It is not a scroll view. It follows the active body's vertical offset by
/// translation, so it is always on the same frame as the grid.
class TimeGutter extends StatelessWidget {
  const TimeGutter({
    super.key,
    required this.scale,
    required this.offset,
    required this.pills,
  });

  final TimeScale scale;
  final ValueListenable<double> offset;
  final List<GutterPill> pills;

  static const double _label = 14;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: GridMetrics.gutter,
      child: ClipRect(
        child: ValueListenableBuilder<double>(
          valueListenable: offset,
          builder: (context, v, child) => Transform.translate(
            offset: Offset(0, -v),
            child: child,
          ),
          child: OverflowBox(
            alignment: Alignment.topCenter,
            minHeight: scale.dayHeight,
            maxHeight: scale.dayHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (var h = 1; h < 24; h++)
                  if (!_covered(h * 60))
                    Positioned(
                      top: scale.px(h * 60) - _label / 2,
                      left: 0,
                      right: 8,
                      height: _label,
                      child: Text(
                        Clock.minutes(h * 60),
                        textAlign: TextAlign.right,
                        style: Type.mono.copyWith(
                          color: Night.mist,
                          fontSize: 10.5,
                          height: _label / 10.5,
                        ),
                      ),
                    ),
                for (final pill in pills)
                  Positioned(
                    top: scale.px(pill.minutes) - 10,
                    left: 3,
                    right: 3,
                    height: 20,
                    child: _Pill(pill: pill),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// An hour label under a pill would print two times on top of each other.
  bool _covered(int minutes) {
    for (final pill in pills) {
      if ((scale.px(pill.minutes) - scale.px(minutes)).abs() < 16) return true;
    }
    return false;
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.pill});

  final GutterPill pill;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: pill.strong ? Night.bone : Night.well,
        borderRadius: const BorderRadius.all(Radius.circular(10)),
      ),
      child: Center(
        child: Text(
          Clock.minutes(pill.minutes.clamp(0, 24 * 60 - 1)),
          style: Type.monoBold.copyWith(
            fontSize: 10.5,
            color: pill.strong ? Night.ink : Night.bone,
          ),
        ),
      ),
    );
  }
}
