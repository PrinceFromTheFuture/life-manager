import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:shopping_list/apps/calendar/data/expand/days.dart';
import 'package:shopping_list/apps/calendar/data/models/place.dart';
import 'package:shopping_list/apps/calendar/data/models/ticket.dart';
import 'package:shopping_list/apps/calendar/state/providers.dart';
import 'package:shopping_list/apps/calendar/ui/grid/day_column.dart';
import 'package:shopping_list/apps/calendar/ui/grid/day_snap_physics.dart';
import 'package:shopping_list/apps/calendar/ui/grid/edge_cue.dart';
import 'package:shopping_list/apps/calendar/ui/grid/event_card.dart';
import 'package:shopping_list/apps/calendar/ui/grid/grid_metrics.dart';
import 'package:shopping_list/apps/calendar/ui/grid/time_gutter.dart';
import 'package:shopping_list/apps/calendar/ui/grid/week_body.dart';
import 'package:shopping_list/apps/calendar/ui/grid/week_nav.dart';
import 'package:shopping_list/apps/calendar/ui/night.dart';
import 'package:shopping_list/core/design/paper_snack.dart';

/// The week: day columns that scroll sideways under a pinned time gutter.
///
/// About 3.3 days fit across, so the next day always peeks in. Past Saturday
/// (or before Sunday) the columns rubber-band and a "Next week" cue arms;
/// letting go there slides the next week in. A horizontal pinch steps between
/// one day, 3.3 and the whole week; a vertical pinch changes the hour height.
class WeekGrid extends ConsumerStatefulWidget {
  const WeekGrid({
    super.key,
    required this.nav,
    required this.onOpenEvent,
    required this.onCreate,
  });

  final WeekNav nav;
  final ValueChanged<Ticket> onOpenEvent;

  /// Opens the drawer for a new event at this time. The ghost block stays on
  /// the grid until it completes.
  final Future<void> Function(DateTime start) onCreate;

  @override
  ConsumerState<WeekGrid> createState() => WeekGridState();
}

class _Body {
  _Body({required this.week, required this.initialH, required this.initialV});

  final DateTime week;
  final double initialH;
  final double initialV;
  final GlobalKey<WeekBodyState> key = GlobalKey<WeekBodyState>();

  WeekBodyState? get state => key.currentState;
}

class _Lift {
  _Lift({
    required this.before,
    required this.resize,
    required this.grab,
    required this.dayIndex,
    required this.start,
    required this.duration,
    required this.pointer,
  }) : bucket = (resize ? start + duration : start) ~/ GridMetrics.tickEvery;

  final Ticket before;
  final bool resize;

  /// Minutes from the edge being dragged — the top, or the bottom for a
  /// resize — to the finger.
  final int grab;
  int dayIndex;

  /// Minutes from [dayIndex]'s midnight. Negative for an overnight event
  /// grabbed on its second day.
  int start;
  int duration;
  Offset pointer;
  int bucket;
}

enum _PinchAxis { hours, days }

class _Pinch {
  _Pinch({
    required this.axis,
    required this.span,
    required this.focal,
    required this.hourHeight,
    required this.density,
    required this.h,
    required this.v,
  });

  final _PinchAxis axis;
  final double span;
  final Offset focal;
  final double hourHeight;
  final double density;
  final double h;
  final double v;
}

class WeekGridState extends ConsumerState<WeekGrid>
    with TickerProviderStateMixin {
  double _hourHeight = GridMetrics.hourHeight;
  double _density = GridMetrics.defaultDensity;
  final _gate = SnapGate();
  final _areaKey = GlobalKey();

  double _viewport = 0;
  double _bodyHeight = 0;

  _Body? _active;
  _Body? _outgoing;
  int _seenSerial = -1;

  final _h = ValueNotifier<double>(0);
  final _v = ValueNotifier<double>(0);
  final _pull = ValueNotifier<Pull>(Pull.none);

  DateTime _now = DateTime.now();
  Timer? _clock;

  _Lift? _lift;
  late final Ticker _autoScroll = createTicker(_onAutoScroll);
  Timer? _dwell;
  int _dwellSide = 0;

  Ghost? _ghost;

  final Map<String, Ticket> _landed = {};
  final Map<DateTime, List<Ticket>> _landedAgainst = {};

  final Map<int, Offset> _pointers = {};
  _Pinch? _pinch;
  bool _pinched = false;
  int? _tracked;
  VelocityTracker? _tracker;

  late final AnimationController _densitySnap = AnimationController(
    vsync: this,
    duration: GridMetrics.drawerHeight,
  );

  TimeScale get scale => TimeScale(_hourHeight);

  ColumnScale get columns => ColumnScale(viewport: _viewport, days: _density);

  bool get _reduced => MediaQuery.disableAnimationsOf(context);

  @override
  void initState() {
    super.initState();
    widget.nav.addListener(_onNav);
    _seenSerial = widget.nav.serial;
    _armClock();
  }

  @override
  void didUpdateWidget(WeekGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.nav != widget.nav) {
      oldWidget.nav.removeListener(_onNav);
      widget.nav.addListener(_onNav);
    }
  }

  @override
  void dispose() {
    widget.nav.removeListener(_onNav);
    _clock?.cancel();
    _dwell?.cancel();
    _autoScroll.dispose();
    _densitySnap.dispose();
    _h.dispose();
    _v.dispose();
    _pull.dispose();
    super.dispose();
  }

  void _armClock() {
    final now = DateTime.now();
    final next = DateTime(now.year, now.month, now.day, now.hour, now.minute + 1);
    _clock = Timer(next.difference(now), () {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
      _clock = Timer.periodic(const Duration(minutes: 1), (_) {
        if (mounted) setState(() => _now = DateTime.now());
      });
    });
  }

  // Week changes.

  void _onNav() {
    final nav = widget.nav;
    if (nav.serial != _seenSerial) {
      _seenSerial = nav.serial;
      final previous = _active;
      final h = previous?.state?.h ?? 0;
      final v = previous?.state?.v ?? _v.value;
      final cols = columns;
      final initialH = switch (nav.landing) {
        Landing.start => 0.0,
        Landing.end => cols.maxOffset,
        Landing.keep => h.clamp(0.0, cols.maxOffset),
        Landing.day => nav.landingDay == null
            ? 0.0
            : cols.offsetFor(Days.between(nav.week, nav.landingDay!)),
      };
      setState(() {
        _outgoing = nav.outgoing != null ? previous : null;
        _active = _Body(
          week: nav.week,
          initialH: initialH,
          initialV: math.max(0, v),
        );
        _pull.value = Pull.none;
      });
      _h.value = initialH;
      _publishLens(initialH);
    } else if (!nav.transitioning && _outgoing != null) {
      setState(() => _outgoing = null);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _consumeReveal());
  }

  void _consumeReveal() {
    if (!mounted) return;
    final body = _active?.state;
    if (body == null || !body.horizontal.hasClients) return;
    final reveal = widget.nav.takeReveal();
    if (reveal == null) return;
    final index = Days.between(widget.nav.week, reveal.at);
    if (index < 0 || index > 6) return;
    final cols = columns;
    final left = index * cols.width;
    final shown = left >= body.h - 1 && left + cols.width <= body.h + cols.viewport + 1;
    if (!shown) {
      _animate(body.horizontal, cols.offsetFor(index));
    }
    if (reveal.time) {
      final target = scale.px(Days.minutesOf(reveal.at)) - _bodyHeight * 0.25;
      _animate(body.vertical, target);
    }
  }

  void _animate(ScrollController controller, double target) {
    if (!controller.hasClients) return;
    final position = controller.position;
    final to = target.clamp(position.minScrollExtent, position.maxScrollExtent);
    if (_reduced) {
      controller.jumpTo(to);
    } else {
      controller.animateTo(to, duration: GridMetrics.reveal, curve: Curves.easeOutCubic);
    }
  }

  /// Scroll [minutes] near the top, for a deep link or a first open.
  void showTime(int minutes) {
    final body = _active?.state;
    if (body == null) return;
    _animate(body.vertical, scale.px(minutes) - _bodyHeight * 0.2);
  }

  void _publishLens(double h) {
    final width = columns.width;
    if (width <= 0) return;
    widget.nav.lens.value = Lens(start: h / width, span: _density);
  }

  // Scroll from the active body.

  void _onScroll(_Body body) {
    if (body != _active) return;
    final state = body.state;
    if (state == null) return;
    _h.value = state.h;
    _v.value = state.v;
    _publishLens(state.h.clamp(0.0, columns.maxOffset));
    _trackPull(state);
  }

  void _trackPull(WeekBodyState state) {
    if (_pointers.isEmpty || _lift != null || _pinch != null) {
      if (_pull.value != Pull.none) _pull.value = Pull.none;
      return;
    }
    if (!state.horizontal.hasClients) return;
    final position = state.horizontal.position;
    var side = 0;
    var distance = 0.0;
    if (position.pixels < position.minScrollExtent) {
      side = -1;
      distance = position.minScrollExtent - position.pixels;
    } else if (position.pixels > position.maxScrollExtent) {
      side = 1;
      distance = position.pixels - position.maxScrollExtent;
    }
    final armed = side != 0 && distance >= GridMetrics.pullArm;
    if (armed != _pull.value.armed) HapticFeedback.selectionClick();
    _pull.value = side == 0
        ? Pull.none
        : Pull(side: side, distance: distance, armed: armed);
  }

  void _releasePull() {
    final state = _active?.state;
    if (state == null || !state.horizontal.hasClients) return;
    final position = state.horizontal.position;
    final velocity = _tracker?.getVelocity().pixelsPerSecond.dx ?? 0;
    final pull = _pull.value;
    _pull.value = Pull.none;

    var side = pull.side;
    if (side == 0) {
      if (position.pixels <= position.minScrollExtent + 0.5) side = -1;
      if (position.pixels >= position.maxScrollExtent - 0.5) side = 1;
      if (position.maxScrollExtent <= 0) side = 0;
    }
    if (side == 0) return;
    // Pulling past Saturday is a finger moving left: negative velocity.
    final fling = side > 0
        ? velocity <= -GridMetrics.pullFling
        : velocity >= GridMetrics.pullFling;
    if (!pull.armed && !fling) return;
    HapticFeedback.mediumImpact();
    widget.nav.step(
      side,
      landing: side > 0 ? Landing.start : Landing.end,
      animate: !_reduced,
    );
  }

  // Pointers: pull release, velocity, pinch.

  void _onPointerDown(PointerDownEvent event) {
    _pointers[event.pointer] = event.position;
    if (_pointers.length == 1) {
      _tracked = event.pointer;
      _tracker = VelocityTracker.withKind(event.kind)
        ..addPosition(event.timeStamp, event.position);
    }
    if (_pointers.length == 2 && _lift == null) _startPinch();
  }

  void _onPointerMove(PointerMoveEvent event) {
    _pointers[event.pointer] = event.position;
    if (event.pointer == _tracked) {
      _tracker?.addPosition(event.timeStamp, event.position);
    }
    if (_pinch != null && _pointers.length >= 2) _updatePinch();
  }

  void _onPointerUp(PointerEvent event) {
    _pointers.remove(event.pointer);
    if (_pinch != null && _pointers.length < 2) _endPinch();
    if (_pointers.isNotEmpty) return;
    // A pinch that ends at the edge is not a pull.
    if (!_pinched && _lift == null && event is PointerUpEvent) _releasePull();
    _pinched = false;
    _tracked = null;
    _tracker = null;
    if (_pull.value != Pull.none) _pull.value = Pull.none;
  }

  Offset? _toArea(Offset global) {
    final box = _areaKey.currentContext?.findRenderObject() as RenderBox?;
    return box?.globalToLocal(global);
  }

  void _startPinch() {
    final body = _active?.state;
    if (body == null) return;
    final points = _pointers.values.take(2).toList();
    final dx = (points[0].dx - points[1].dx).abs();
    final dy = (points[0].dy - points[1].dy).abs();
    final axis = dx > dy ? _PinchAxis.days : _PinchAxis.hours;
    final focal = _toArea((points[0] + points[1]) / 2);
    if (focal == null) return;
    _densitySnap.stop();
    _gate.open = false;
    _pinched = true;
    _pull.value = Pull.none;
    _pinch = _Pinch(
      axis: axis,
      span: math.max(40, axis == _PinchAxis.days ? dx : dy),
      focal: focal,
      hourHeight: _hourHeight,
      density: _density,
      h: body.h,
      v: body.v,
    );
  }

  void _updatePinch() {
    final pinch = _pinch;
    final body = _active?.state;
    if (pinch == null || body == null) return;
    final points = _pointers.values.take(2).toList();
    final span = pinch.axis == _PinchAxis.days
        ? (points[0].dx - points[1].dx).abs()
        : (points[0].dy - points[1].dy).abs();
    final ratio = math.max(40, span) / pinch.span;

    if (pinch.axis == _PinchAxis.hours) {
      final next = (pinch.hourHeight * ratio)
          .clamp(GridMetrics.minHourHeight, GridMetrics.maxHourHeight);
      final focalY = pinch.focal.dy - GridMetrics.header - 1;
      final content = pinch.v + focalY;
      final v = content * (next / pinch.hourHeight) - focalY;
      setState(() => _hourHeight = next);
      if (body.vertical.hasClients) body.vertical.jumpTo(math.max(0, v));
    } else {
      final next = (pinch.density / ratio)
          .clamp(GridMetrics.densities.first, GridMetrics.densities.last);
      _setDensity(next, focalX: pinch.focal.dx, fromDensity: pinch.density, fromH: pinch.h);
    }
  }

  void _setDensity(
    double density, {
    required double focalX,
    required double fromDensity,
    required double fromH,
  }) {
    final body = _active?.state;
    final content = fromH + focalX;
    final h = content * (fromDensity / density) - focalX;
    setState(() => _density = density);
    if (body != null && body.horizontal.hasClients) {
      body.horizontal.jumpTo(h.clamp(0.0, columns.maxOffset));
    }
    _publishLens(h.clamp(0.0, columns.maxOffset));
  }

  void _endPinch() {
    final pinch = _pinch;
    _pinch = null;
    if (pinch == null) return;
    if (pinch.axis == _PinchAxis.hours) {
      _gate.open = true;
      return;
    }
    final target = GridMetrics.densities.reduce(
      (a, b) => (math.log(a) - math.log(_density)).abs() <=
              (math.log(b) - math.log(_density)).abs()
          ? a
          : b,
    );
    final from = _density;
    final fromH = _active?.state?.h ?? 0;
    final focalX = pinch.focal.dx;
    if (target != pinch.density) HapticFeedback.selectionClick();
    void land() {
      _gate.open = true;
      _settleColumns();
    }

    if (_reduced || (target - from).abs() < 0.01) {
      _setDensity(target, focalX: focalX, fromDensity: from, fromH: fromH);
      land();
      return;
    }
    final curve = CurvedAnimation(parent: _densitySnap, curve: GridMetrics.ease);
    void tick() {
      final d = from + (target - from) * curve.value;
      _setDensity(d, focalX: focalX, fromDensity: from, fromH: fromH);
    }

    _densitySnap
      ..removeListener(tick)
      ..addListener(tick);
    _densitySnap.forward(from: 0).whenCompleteOrCancel(() {
      _densitySnap.removeListener(tick);
      curve.dispose();
      land();
    });
  }

  /// Rest on the nearest column after a pinch or a lift moved freely.
  void _settleColumns() {
    final body = _active?.state;
    if (body == null || !body.horizontal.hasClients) return;
    final cols = columns;
    final h = body.h;
    var target = (h / cols.width).round() * cols.width;
    if (h > cols.maxOffset - cols.width / 2) target = cols.maxOffset;
    _animate(body.horizontal, target);
  }

  // Tap to create.

  Future<void> _onTapEmpty(DateTime day, double y) async {
    if (_lift != null || _ghost != null) return;
    final slot = (scale.minutes(y) / GridMetrics.tapSnap).floor() * GridMetrics.tapSnap;
    final minutes = slot.clamp(0, 24 * 60 - GridMetrics.tapSnap);
    final start = Days.atMinutes(day, minutes);
    unawaited(HapticFeedback.selectionClick());
    setState(() => _ghost = Ghost(start: start, duration: 60));

    final body = _active?.state;
    if (body != null && body.vertical.hasClients) {
      final top = scale.px(minutes);
      final onScreen = top - body.v;
      if (onScreen < 0 || onScreen > _bodyHeight * 0.32) {
        _animate(body.vertical, top - 24);
      }
    }
    await widget.onCreate(start);
    if (mounted) setState(() => _ghost = null);
  }

  // Lift.

  int _minutesAt(Offset local, WeekBodyState body) =>
      scale.minutes(local.dy - GridMetrics.header - 1 + body.v).floor();

  int _dayAt(Offset local, WeekBodyState body) =>
      ((local.dx + body.h) / columns.width).floor().clamp(0, 6);

  void _onLift(LiftStart start) {
    final body = _active?.state;
    final local = _toArea(start.global);
    if (body == null || local == null || _pinch != null) return;
    final dayIndex = _dayAt(local, body);
    final columnDay = Days.addDays(widget.nav.week, dayIndex);
    final ticket = start.ticket;
    final startRel = Days.between(columnDay, ticket.startsAt) * 24 * 60 +
        Days.minutesOf(ticket.startsAt);
    HapticFeedback.mediumImpact();
    _gate.open = false;
    _pull.value = Pull.none;
    setState(() {
      _lift = _Lift(
        before: ticket,
        resize: start.resize,
        grab: _minutesAt(local, body) -
            (start.resize ? startRel + ticket.durationMinutes : startRel),
        dayIndex: dayIndex,
        start: startRel,
        duration: ticket.durationMinutes,
        pointer: start.global,
      );
    });
    if (!_autoScroll.isActive) _autoScroll.start();
  }

  void _onLiftMove(Offset global) {
    final lift = _lift;
    if (lift == null) return;
    lift.pointer = global;
    _retarget();
  }

  void _retarget() {
    final lift = _lift;
    final body = _active?.state;
    if (lift == null || body == null) return;
    final local = _toArea(lift.pointer);
    if (local == null) return;
    final pointer = _minutesAt(local, body);

    var day = lift.dayIndex;
    var start = lift.start;
    var duration = lift.duration;
    if (lift.resize) {
      final end = GridMetrics.snap(pointer - lift.grab, GridMetrics.dragSnap);
      duration = math.max(GridMetrics.minDuration, end - start);
      duration = math.min(duration, 24 * 60 * 2 - start);
    } else {
      day = _dayAt(local, body);
      start = GridMetrics.snap(pointer - lift.grab, GridMetrics.dragSnap)
          .clamp(0, 24 * 60 - GridMetrics.dragSnap);
    }
    if (day == lift.dayIndex && start == lift.start && duration == lift.duration) {
      return;
    }
    final bucket = (lift.resize ? start + duration : start) ~/ GridMetrics.tickEvery;
    if (bucket != lift.bucket || day != lift.dayIndex) {
      HapticFeedback.selectionClick();
    }
    setState(() {
      lift
        ..dayIndex = day
        ..start = start
        ..duration = duration
        ..bucket = bucket;
    });
  }

  void _onAutoScroll(Duration _) {
    final lift = _lift;
    final body = _active?.state;
    if (lift == null) {
      _autoScroll.stop();
      return;
    }
    if (body == null || !body.vertical.hasClients || !body.horizontal.hasClients) {
      return;
    }
    final local = _toArea(lift.pointer);
    if (local == null) return;
    const zone = GridMetrics.autoScrollZone;
    const max = GridMetrics.autoScrollMax;

    final y = local.dy - GridMetrics.header - 1;
    var dv = 0.0;
    if (y < zone) {
      dv = -max * (1 - (y / zone)).clamp(0.0, 1.0);
    } else if (y > _bodyHeight - zone) {
      dv = max * (1 - ((_bodyHeight - y) / zone)).clamp(0.0, 1.0);
    }
    var moved = false;
    if (dv != 0) {
      final position = body.vertical.position;
      final next = (body.v + dv).clamp(0.0, position.maxScrollExtent);
      if (next != body.v) {
        body.vertical.jumpTo(next);
        moved = true;
      }
    }

    var side = 0;
    if (!lift.resize) {
      var dh = 0.0;
      if (local.dx < zone) {
        dh = -max * (1 - (local.dx / zone)).clamp(0.0, 1.0);
      } else if (local.dx > _viewport - zone) {
        dh = max * (1 - ((_viewport - local.dx) / zone)).clamp(0.0, 1.0);
      }
      if (dh != 0) {
        final position = body.horizontal.position;
        final next = (body.h + dh).clamp(0.0, position.maxScrollExtent);
        if (next != body.h) {
          body.horizontal.jumpTo(next);
          moved = true;
        } else {
          side = dh > 0 ? 1 : -1;
        }
      }
    }
    _armDwell(side);
    if (moved) _retarget();
  }

  /// Holding a lifted event against the week's edge turns the page.
  void _armDwell(int side) {
    if (side == _dwellSide && (_dwell != null || side == 0)) return;
    _dwell?.cancel();
    _dwell = null;
    _dwellSide = side;
    if (side == 0) return;
    _dwell = Timer(GridMetrics.dwell, () {
      _dwell = null;
      _dwellSide = 0;
      if (_lift == null || !mounted) return;
      HapticFeedback.mediumImpact();
      widget.nav.step(
        side,
        landing: side > 0 ? Landing.start : Landing.end,
        animate: !_reduced,
      );
    });
  }

  void _endLift() {
    _autoScroll.stop();
    _dwell?.cancel();
    _dwell = null;
    _dwellSide = 0;
    _gate.open = true;
    _settleColumns();
  }

  void _onLiftCancel() {
    if (_lift == null) return;
    _endLift();
    setState(() => _lift = null);
  }

  Future<void> _onDrop() async {
    final lift = _lift;
    if (lift == null) return;
    _endLift();
    final before = lift.before;
    final startsAt = lift.resize
        ? before.startsAt
        : Days.atMinutes(Days.addDays(widget.nav.week, lift.dayIndex), lift.start);
    final duration = lift.duration;
    if (startsAt == before.startsAt && duration == before.durationMinutes) {
      setState(() => _lift = null);
      return;
    }
    unawaited(HapticFeedback.lightImpact());
    final moved = before.copyWith(startsAt: startsAt, durationMinutes: duration);
    final weeks = {Days.startOfWeek(before.startsAt), Days.startOfWeek(startsAt)};
    setState(() {
      _lift = null;
      _landed[before.key] = moved;
      for (final week in weeks) {
        _landedAgainst[week] =
            ref.read(weekTicketsProvider(week)).valueOrNull ?? const [];
      }
    });

    final controller = ref.read(calendarControllerProvider);
    await controller.reschedule(before, startsAt: startsAt, durationMinutes: duration);
    if (!mounted) return;
    final when = lift.resize
        ? '${DateFormat('EEE HH:mm').format(startsAt)}–'
            '${DateFormat('HH:mm').format(moved.endsAt)}'
        : DateFormat('EEE HH:mm').format(startsAt);
    showPaperSnack(
      context,
      message: before.fromRegistry ? '$when · This time only' : when,
      actionLabel: 'Undo',
      onAction: () => unawaited(controller.undoMove(before)),
    );
  }

  // Data.

  List<Ticket> _ticketsFor(DateTime week) {
    final async = ref.watch(weekTicketsProvider(week));
    final base = async.valueOrNull ?? const <Ticket>[];
    final against = _landedAgainst[week];
    if (against != null && !identical(against, base) && !async.isLoading) {
      // The write has come back from the database; the real row replaces the
      // optimistic one.
      _landedAgainst.clear();
      _landed.clear();
    }
    if (_landed.isEmpty) return base;
    final end = Days.addDays(week, 7);
    return [
      for (final ticket in base)
        if (!_landed.containsKey(ticket.key)) ticket,
      for (final ticket in _landed.values)
        if (ticket.startsAt.isBefore(end) && ticket.endsAt.isAfter(week)) ticket,
    ];
  }

  Widget _bodyFor(_Body body, Map<int, Place> places, ColumnActions actions) {
    return WeekBody(
      key: body.key,
      week: body.week,
      tickets: _ticketsFor(body.week),
      places: places,
      columns: columns,
      scale: scale,
      gate: _gate,
      now: _now,
      actions: actions,
      initialH: body.initialH,
      initialV: body.initialV,
      onScroll: () => _onScroll(body),
      liftKey: _lift?.before.key,
      ghost: _ghost,
    );
  }

  double _initialV() {
    final now = DateTime.now();
    return math.max(0, scale.px(Days.minutesOf(now) - 90));
  }

  @override
  Widget build(BuildContext context) {
    final nav = widget.nav;
    // Neighbours stay warm so a week switch lands on painted columns.
    ref.watch(weekTicketsProvider(Days.addDays(nav.week, -7)));
    ref.watch(weekTicketsProvider(Days.addDays(nav.week, 7)));
    final places = {
      for (final place in ref.watch(placesProvider).valueOrNull ?? const <Place>[])
        if (place.id != null) place.id!: place,
    };
    final actions = ColumnActions(
      onTapEmpty: _onTapEmpty,
      onTapEvent: (ticket) {
        if (_lift == null) widget.onOpenEvent(ticket);
      },
      onLift: _onLift,
      onMove: _onLiftMove,
      onDrop: _onDrop,
      onCancel: _onLiftCancel,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        _viewport = math.max(1, constraints.maxWidth - GridMetrics.gutter);
        _bodyHeight = math.max(1, constraints.maxHeight - GridMetrics.header - 1);
        if (_active == null) {
          final todayIndex = Days.between(nav.week, _now);
          final initialV = _initialV();
          _active = _Body(
            week: nav.week,
            initialH: todayIndex >= 0 && todayIndex < 7
                ? columns.offsetFor(todayIndex)
                : 0,
            initialV: initialV,
          );
          _v.value = initialV;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _publishLens(_active!.initialH);
            _consumeReveal();
          });
        }

        final active = _bodyFor(_active!, places, actions);
        final outgoing = _outgoing == null ? null : _bodyFor(_outgoing!, places, actions);

        return Listener(
          onPointerDown: _onPointerDown,
          onPointerMove: _onPointerMove,
          onPointerUp: _onPointerUp,
          onPointerCancel: _onPointerUp,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Column(
                children: [
                  const SizedBox(
                    width: GridMetrics.gutter,
                    height: GridMetrics.header + 1,
                  ),
                  Expanded(
                    child: TimeGutter(
                      scale: scale,
                      offset: _v,
                      pills: _pills(),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: KeyedSubtree(
                  key: _areaKey,
                  child: ClipRect(
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: AnimatedBuilder(
                            animation: nav.progress,
                            builder: (context, _) {
                              final moving = outgoing != null && nav.transitioning;
                              final t = moving ? nav.progress.value : 1.0;
                              final width = _viewport;
                              final dir = nav.direction.toDouble();
                              return Stack(
                                children: [
                                  if (moving)
                                    Positioned.fill(
                                      child: Transform.translate(
                                        offset: Offset(-dir * width * t, 0),
                                        child: IgnorePointer(child: outgoing),
                                      ),
                                    ),
                                  Positioned.fill(
                                    child: Transform.translate(
                                      offset: Offset(dir * width * (1 - t), 0),
                                      child: active,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        Positioned.fill(
                          top: GridMetrics.header + 1,
                          child: EdgeCue(
                            pull: _pull,
                            label: (side) => side > 0 ? 'Next week' : 'Previous week',
                          ),
                        ),
                        if (_lift != null)
                          Positioned.fill(
                            top: GridMetrics.header + 1,
                            child: IgnorePointer(child: _liftedCard(places)),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<GutterPill> _pills() {
    final lift = _lift;
    final todayShown = Days.between(widget.nav.week, _now);
    final pills = <GutterPill>[
      if (todayShown >= 0 && todayShown < 7)
        GutterPill(minutes: Days.minutesOf(_now), strong: lift == null),
    ];
    if (lift != null) {
      final start = lift.start.clamp(0, 24 * 60 - 1);
      pills.add(GutterPill(minutes: start, strong: true));
      if (lift.resize) {
        pills.add(
          GutterPill(
            minutes: (lift.start + lift.duration).clamp(0, 24 * 60 - 1),
            strong: true,
          ),
        );
      }
    }
    return pills;
  }

  Widget _liftedCard(Map<int, Place> places) {
    final lift = _lift!;
    final cols = columns;
    final ticket = lift.before.copyWith(
      startsAt: Days.atMinutes(
        Days.addDays(widget.nav.week, lift.dayIndex),
        lift.start,
      ),
      durationMinutes: lift.duration,
    );
    final place = ticket.locationId == null ? null : places[ticket.locationId!];
    final drawn = math.max(lift.duration, GridMetrics.minCardMinutes);
    final height = scale.px(drawn) - 2;
    final compact = cols.days >= GridMetrics.compactDensity;

    return ListenableBuilder(
      listenable: Listenable.merge([_h, _v]),
      builder: (context, _) => Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: lift.dayIndex * cols.width - _h.value + 2,
            top: scale.px(lift.start) - _v.value + 1,
            width: cols.width - 4,
            height: height,
            child: Transform.scale(
              scale: 1.03,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  EventCard(
                    ticket: ticket,
                    place: place,
                    height: height,
                    compact: compact,
                    lifted: true,
                    animateIn: false,
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 3),
                      width: 18,
                      height: 3,
                      decoration: BoxDecoration(
                        color: Night.bone.withValues(alpha: lift.resize ? 0.9 : 0.35),
                        borderRadius: const BorderRadius.all(Radius.circular(2)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
