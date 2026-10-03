import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

/// Lets a pinch or a lift move the columns freely without the physics pulling
/// them back to a boundary after every frame.
class SnapGate {
  bool open = true;
}

/// Horizontal physics that come to rest on whole day columns.
///
/// Built on [BouncingScrollPhysics] on every platform: the edge overscroll is
/// what the week pull reads, so it has to exist on Android too. A fling is
/// projected to where friction would stop it and then rounded to a column, so
/// a quick flick travels several days and a slow drag settles on the nearest.
class DaySnapPhysics extends BouncingScrollPhysics {
  const DaySnapPhysics({
    required this.columnWidth,
    required this.gate,
    super.parent,
  });

  final double columnWidth;
  final SnapGate gate;

  @override
  DaySnapPhysics applyTo(ScrollPhysics? ancestor) => DaySnapPhysics(
        columnWidth: columnWidth,
        gate: gate,
        parent: buildParent(ancestor),
      );

  /// Overscroll resists harder than stock: the pull is a deliberate gesture,
  /// not a rubber band to play with.
  @override
  double frictionFactor(double overscrollFraction) =>
      0.42 * (1 - overscrollFraction) * (1 - overscrollFraction);

  static final SpringDescription _spring =
      SpringDescription.withDampingRatio(mass: 0.5, stiffness: 140, ratio: 1.05);

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    if (position.outOfRange || !gate.open || columnWidth <= 0) {
      return super.createBallisticSimulation(position, velocity);
    }
    final tolerance = toleranceFor(position);
    final projected = velocity.abs() < tolerance.velocity
        ? position.pixels
        : FrictionSimulation(0.135, position.pixels, velocity).finalX;

    var target = (projected / columnWidth).round() * columnWidth;
    // The last stop is the week's end, which is rarely a whole column away.
    if (projected > position.maxScrollExtent - columnWidth / 2) {
      target = position.maxScrollExtent;
    }
    target = target.clamp(position.minScrollExtent, position.maxScrollExtent);

    if ((target - position.pixels).abs() < tolerance.distance &&
        velocity.abs() < tolerance.velocity) {
      return null;
    }
    return ScrollSpringSimulation(
      _spring,
      position.pixels,
      target,
      velocity,
      tolerance: tolerance,
    );
  }

  @override
  bool get allowImplicitScrolling => false;
}
