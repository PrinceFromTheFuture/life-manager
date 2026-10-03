import 'package:flutter/animation.dart';

/// Every number the week grid, the strip and the drawer agree on.
abstract final class GridMetrics {
  // Layout.
  static const double gutter = 52;
  static const double header = 56;
  static const double hourHeight = 72;
  static const double minHourHeight = 64;
  static const double maxHourHeight = 180;

  /// Days across the viewport. The middle one is the resting state: a third
  /// of a fourth day always peeks in, so there is visibly more to the right.
  static const List<double> densities = [1, 3.3, 7];
  static const double defaultDensity = 3.3;

  /// Below this many visible days a card shows its full tiers; at seven it is
  /// a sliver and only the title fits.
  static const double compactDensity = 5;

  /// Shortest a card is drawn, in minutes. Overlap layout claims the same.
  static const int minCardMinutes = 15;

  // Snapping.
  static const int tapSnap = 15;
  static const int dragSnap = 5;
  static const int tickEvery = 15;
  static const int minDuration = 15;

  // Press.
  static const Duration pressDelay = Duration(milliseconds: 220);
  static const double pressSlop = 10;
  static const double tapSlop = 8;

  // Auto-scroll and dwell.
  static const double autoScrollZone = 72;
  static const double autoScrollMax = 12;
  static const Duration dwell = Duration(milliseconds: 600);

  // Edge pull.
  static const double pullLabel = 24;
  static const double pullArm = 72;

  /// Pixels per second. A fling this fast at the edge arms the pull even
  /// short of [pullArm].
  static const double pullFling = 400;

  // Strip swipe.
  static const double stripDistance = 36;
  static const double stripVelocity = 300;
  static const double stripFollow = 0.6;

  // Motion.
  static const Duration weekSlide = Duration(milliseconds: 340);
  static const Duration drawerSlide = Duration(milliseconds: 500);
  static const Duration drawerHeight = Duration(milliseconds: 220);
  static const Duration viewSwitch = Duration(milliseconds: 150);
  static const Duration reveal = Duration(milliseconds: 280);
  static const Duration cardMount = Duration(milliseconds: 200);

  /// vaul's curve. The drawer, the week slide and the density snap all use it
  /// so every big movement in the app decelerates the same way.
  static const Curve ease = Cubic(0.32, 0.72, 0, 1);

  static const SpringDescription candidate = SpringDescription(
    mass: 1,
    stiffness: 500,
    damping: 40,
  );

  static int snap(num minutes, int step) => (minutes / step).round() * step;
}

/// Minutes to pixels at one hour height.
class TimeScale {
  const TimeScale(this.hourHeight);

  final double hourHeight;

  double get perMinute => hourHeight / 60;

  double get dayHeight => hourHeight * 24;

  double px(num minutes) => minutes * perMinute;

  double minutes(double px) => px / perMinute;
}

/// Column geometry for a viewport width and a density.
class ColumnScale {
  const ColumnScale({required this.viewport, required this.days});

  /// Width of the scrolling area, gutter excluded.
  final double viewport;

  /// Days visible across [viewport].
  final double days;

  double get width => viewport / days;

  double get content => width * 7;

  double get maxOffset => (content - viewport).clamp(0, double.infinity);

  /// Offset that puts [index] at the left edge, as far as the week allows.
  double offsetFor(int index) => (index * width).clamp(0, maxOffset);
}
