import 'package:flutter/gestures.dart';

import 'package:shopping_list/apps/calendar/ui/grid/grid_metrics.dart';

/// Press, hold, then drag — and nothing else.
///
/// A stock long-press waits for the platform slop (18 px) before it gives up,
/// which lets a slow scroll turn into an accidental lift. This one gives up at
/// [GridMetrics.pressSlop], well before the scroll views claim the pointer, so
/// a finger that is already moving always scrolls. Once lifted it keeps the
/// pointer however far it travels.
class LiftRecognizer extends PrimaryPointerGestureRecognizer {
  LiftRecognizer({super.debugOwner})
      : super(
          deadline: GridMetrics.pressDelay,
          preAcceptSlopTolerance: GridMetrics.pressSlop,
          postAcceptSlopTolerance: null,
        );

  /// Global position of the press, once held long enough.
  GestureLongPressStartCallback? onLift;
  GestureDragUpdateCallback? onMove;
  GestureDragEndCallback? onDrop;
  GestureDragCancelCallback? onCancel;

  bool _deadlinePassed = false;
  bool _accepted = false;
  bool _lifted = false;
  VelocityTracker? _velocity;

  @override
  void didExceedDeadline() {
    _deadlinePassed = true;
    resolve(GestureDisposition.accepted);
    _maybeLift();
  }

  @override
  void acceptGesture(int pointer) {
    super.acceptGesture(pointer);
    _accepted = true;
    _maybeLift();
  }

  void _maybeLift() {
    if (_lifted || !_accepted || !_deadlinePassed) return;
    _lifted = true;
    final at = initialPosition;
    if (at == null) return;
    onLift?.call(
      LongPressStartDetails(globalPosition: at.global, localPosition: at.local),
    );
  }

  @override
  void handlePrimaryPointer(PointerEvent event) {
    if (!_lifted) {
      // Let go before the deadline: this was a tap.
      if (event is PointerUpEvent || event is PointerCancelEvent) {
        resolve(GestureDisposition.rejected);
      }
      return;
    }
    if (event is PointerMoveEvent) {
      (_velocity ??= VelocityTracker.withKind(event.kind))
          .addPosition(event.timeStamp, event.position);
      onMove?.call(
        DragUpdateDetails(
          globalPosition: event.position,
          localPosition: event.localPosition,
          delta: event.delta,
          sourceTimeStamp: event.timeStamp,
        ),
      );
    } else if (event is PointerUpEvent) {
      onDrop?.call(
        DragEndDetails(
          velocity: _velocity?.getVelocity() ?? Velocity.zero,
          globalPosition: event.position,
        ),
      );
      _reset();
    } else if (event is PointerCancelEvent) {
      onCancel?.call();
      _reset();
    }
  }

  @override
  void rejectGesture(int pointer) {
    if (_lifted) onCancel?.call();
    _reset();
    super.rejectGesture(pointer);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    _reset();
    super.didStopTrackingLastPointer(pointer);
  }

  void _reset() {
    _deadlinePassed = false;
    _accepted = false;
    _lifted = false;
    _velocity = null;
  }

  @override
  String get debugDescription => 'lift';
}
