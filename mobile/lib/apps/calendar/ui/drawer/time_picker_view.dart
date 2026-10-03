import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:shopping_list/apps/calendar/data/clock.dart';
import 'package:shopping_list/apps/calendar/data/expand/days.dart';
import 'package:shopping_list/apps/calendar/data/expand/slices.dart';
import 'package:shopping_list/apps/calendar/data/models/ticket.dart';
import 'package:shopping_list/apps/calendar/state/providers.dart';
import 'package:shopping_list/apps/calendar/ui/drawer/drawer_parts.dart';
import 'package:shopping_list/apps/calendar/ui/grid/grid_metrics.dart';
import 'package:shopping_list/apps/calendar/ui/grid/week_nav.dart';
import 'package:shopping_list/apps/calendar/ui/night.dart';
import 'package:shopping_list/apps/calendar/ui/week_strip.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/design/widgets/app_icon.dart';
import 'package:shopping_list/core/design/widgets/multi_view_drawer.dart';

/// Place an event by putting it where it goes.
///
/// One day at a time under the week strip. The candidate is the only bright
/// thing on the column: it moves the moment a finger lands on it, in five
/// minute steps, and its bottom edge stretches the duration. Tapping empty
/// time centres the block there on a spring. Everything already booked is
/// dimmed underneath, and an overlap is mentioned, never refused.
class TimePickerView extends ConsumerStatefulWidget {
  const TimePickerView({
    super.key,
    required this.start,
    required this.duration,
    required this.onConfirm,
    this.title = 'Pick a time',
    this.confirmLabel = 'Set time',
    this.excludeKey,
    this.label,
  });

  final DateTime start;
  final int duration;
  final void Function(DateTime start, int duration) onConfirm;
  final String title;
  final String confirmLabel;

  /// The event being placed, left out of the dimmed layer and overlap check.
  final String? excludeKey;

  /// Name shown on the candidate.
  final String? label;

  static const double hourHeight = 72;

  @override
  ConsumerState<TimePickerView> createState() => TimePickerViewState();
}

enum _Grip { move, resize }

class TimePickerViewState extends ConsumerState<TimePickerView>
    with TickerProviderStateMixin {
  static const _scale = TimeScale(TimePickerView.hourHeight);
  static const _gutter = GridMetrics.gutter;
  static const _pad = 12.0;
  static const _edgeZone = 48.0;
  static const _edgeSpeed = 10.0;
  static const _resizeZone = 18.0;

  late final WeekNav _nav = WeekNav(vsync: this, week: widget.start)
    ..addListener(_onWeek);
  late DateTime _day = Days.startOfDay(widget.start);
  late int _start = Days.minutesOf(widget.start);
  late int _duration = widget.duration;

  final _scroll = ScrollController();
  final _columnKey = GlobalKey();
  final _viewportKey = GlobalKey();
  late final AnimationController _top = AnimationController.unbounded(
    vsync: this,
    value: _scale.px(_start),
  );
  late final Ticker _edge = createTicker(_onEdge);

  _Grip? _grip;
  double _grab = 0;
  Offset _pointer = Offset.zero;
  int _bucket = 0;
  DateTime _week = Days.startOfWeek(DateTime.now());

  int get start => _start;
  int get duration => _duration;
  DateTime get day => _day;

  bool get _reduced => MediaQuery.disableAnimationsOf(context);

  @override
  void initState() {
    super.initState();
    _week = _nav.week;
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCandidate(animate: false));
  }

  @override
  void dispose() {
    _nav
      ..removeListener(_onWeek)
      ..dispose();
    _scroll.dispose();
    _top.dispose();
    _edge.dispose();
    super.dispose();
  }

  /// A strip swipe keeps the weekday: Tuesday stays Tuesday a week on.
  void _onWeek() {
    if (_nav.week == _week) return;
    _week = _nav.week;
    setState(() => _day = Days.addDays(_nav.week, _day.weekday % 7));
  }

  void _select(DateTime day) {
    if (Days.isSameDay(day, _day)) return;
    HapticFeedback.selectionClick();
    setState(() => _day = Days.startOfDay(day));
  }

  void _scrollToCandidate({required bool animate}) {
    if (!_scroll.hasClients) return;
    final viewport = _scroll.position.viewportDimension;
    final target = (_scale.px(_start) + _pad - viewport * 0.3)
        .clamp(0.0, _scroll.position.maxScrollExtent);
    if (animate && !_reduced) {
      _scroll.animateTo(target, duration: GridMetrics.reveal, curve: GridMetrics.ease);
    } else {
      _scroll.jumpTo(target);
    }
  }

  void _springTo(double target) {
    if (_reduced) {
      _top.value = target;
      return;
    }
    _top.animateWith(SpringSimulation(GridMetrics.candidate, _top.value, target, 0));
  }

  int _clampStart(int minutes) => minutes.clamp(0, math.max(0, 24 * 60 - _duration));

  /// Content y, scroll included, for a global point.
  double? _contentY(Offset global) {
    final box = _columnKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.globalToLocal(global).dy;
  }

  void _onTapColumn(TapUpDetails details) {
    if (_grip != null) return;
    final minutes = _scale.minutes(details.localPosition.dy).round();
    final next = _clampStart(GridMetrics.snap(minutes - _duration ~/ 2, GridMetrics.dragSnap));
    HapticFeedback.selectionClick();
    setState(() => _start = next);
    _springTo(_scale.px(next));
  }

  void _onDown(PointerDownEvent event) {
    final height = _scale.px(_duration);
    final local = event.localPosition.dy;
    _grip = local > height - _resizeZone && height >= 30 ? _Grip.resize : _Grip.move;
    // Distance from the finger to the edge it holds, so nothing jumps on grab.
    _grab = _grip == _Grip.resize ? local - height : local;
    _pointer = event.position;
    _bucket = _bucketFor();
    _top.stop();
    HapticFeedback.selectionClick();
    setState(() {});
    if (!_edge.isActive) _edge.start();
  }

  void _onMove(PointerMoveEvent event) {
    if (_grip == null) return;
    _pointer = event.position;
    _retarget();
  }

  void _onUp(PointerEvent event) {
    if (_grip == null) return;
    _edge.stop();
    setState(() => _grip = null);
    _springTo(_scale.px(_start));
  }

  int _bucketFor() => (_grip == _Grip.resize ? _start + _duration : _start) ~/ GridMetrics.tickEvery;

  void _retarget() {
    final y = _contentY(_pointer);
    if (y == null) return;
    var start = _start;
    var duration = _duration;
    if (_grip == _Grip.resize) {
      final end = GridMetrics.snap(_scale.minutes(y - _grab).round(), GridMetrics.dragSnap);
      duration = (end - start).clamp(GridMetrics.minDuration, 24 * 60 - start);
    } else {
      final top = _scale.minutes(y - _grab).round();
      start = _clampStart(GridMetrics.snap(top, GridMetrics.dragSnap));
    }
    if (start == _start && duration == _duration) return;
    setState(() {
      _start = start;
      _duration = duration;
    });
    _top.value = _scale.px(start);
    final bucket = _bucketFor();
    if (bucket != _bucket) {
      _bucket = bucket;
      HapticFeedback.selectionClick();
    }
  }

  void _onEdge(Duration _) {
    if (_grip == null || !_scroll.hasClients) return;
    final box = _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final y = box.globalToLocal(_pointer).dy;
    final height = box.size.height;
    var dv = 0.0;
    if (y < _edgeZone) {
      dv = -_edgeSpeed * (1 - y / _edgeZone).clamp(0.0, 1.0);
    } else if (y > height - _edgeZone) {
      dv = _edgeSpeed * (1 - (height - y) / _edgeZone).clamp(0.0, 1.0);
    }
    if (dv == 0) return;
    final next = (_scroll.offset + dv).clamp(0.0, _scroll.position.maxScrollExtent);
    if (next == _scroll.offset) return;
    _scroll.jumpTo(next);
    _retarget();
  }

  void _confirm() {
    widget.onConfirm(Days.atMinutes(_day, _start), _duration);
  }

  List<int> _loads(DateTime week) =>
      dayLoads(week, ref.watch(weekTicketsProvider(week)).valueOrNull ?? const []);

  @override
  Widget build(BuildContext context) {
    final tickets = ref.watch(weekTicketsProvider(_nav.week)).valueOrNull ?? const <Ticket>[];
    final slices = [
      for (final slice in Slices.onDay(_day, tickets))
        if (slice.ticket.key != widget.excludeKey) slice,
    ];
    final end = _start + _duration;
    final clashes = [
      for (final slice in slices)
        if (slice.topMinutes < end && slice.topMinutes + slice.durationMinutes > _start) slice,
    ];
    final now = DateTime.now();
    final startsAt = Days.atMinutes(_day, _start);
    final past = startsAt.isBefore(now);
    final today = Days.isSameDay(_day, now);
    final dayStart = Days.startOfDay(_day);
    final pastUntil = Days.startOfDay(now).isAfter(dayStart)
        ? 24 * 60
        : (today ? Days.minutesOf(now) : 0);

    return Column(
      children: [
        DrawerViewHeader(
          title: widget.title,
          trailing: Text(
            DateFormat('MMMM').format(_day),
            style: Type.item.copyWith(color: Night.mist),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.sm),
          child: WeekStrip(
            nav: _nav,
            loads: _loads,
            onTapDay: _select,
            showLens: false,
            selected: _day,
          ),
        ),
        const SizedBox(height: Space.xs),
        const Divider(height: 1, thickness: 1, color: Night.line),
        Expanded(
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (rect) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x00000000), Color(0xFF000000), Color(0xFF000000), Color(0x00000000)],
              stops: [0, 0.04, 0.96, 1],
            ).createShader(rect),
            child: SingleChildScrollView(
              key: _viewportKey,
              controller: _scroll,
              physics: _grip != null
                  ? const NeverScrollableScrollPhysics()
                  : const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: _pad),
              child: SizedBox(
                height: _scale.dayHeight,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: _gutter,
                      child: _Hours(
                        scale: _scale,
                        highlight: [_start, if (_grip == _Grip.resize) end],
                        live: _grip != null,
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: Space.md),
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapUp: _onTapColumn,
                          child: Stack(
                            key: _columnKey,
                            clipBehavior: Clip.none,
                            children: [
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: _PickerRules(scale: _scale, pastUntil: pastUntil),
                                ),
                              ),
                              Positioned.fill(
                                child: AnimatedSwitcher(
                                  duration: _reduced ? Duration.zero : GridMetrics.viewSwitch,
                                  child: _Booked(
                                    key: ValueKey(_day),
                                    slices: slices,
                                    scale: _scale,
                                  ),
                                ),
                              ),
                              if (today)
                                Positioned(
                                  top: _scale.px(Days.minutesOf(now)) - 1,
                                  left: 0,
                                  right: 0,
                                  height: 2,
                                  child: const IgnorePointer(
                                    child: ColoredBox(color: Night.bone),
                                  ),
                                ),
                              AnimatedBuilder(
                                animation: _top,
                                builder: (context, child) => Positioned(
                                  top: _top.value,
                                  left: 0,
                                  right: 0,
                                  height: math.max(24.0, _scale.px(_duration)),
                                  child: child!,
                                ),
                                child: RawGestureDetector(
                                  gestures: {
                                    EagerGestureRecognizer:
                                        GestureRecognizerFactoryWithHandlers<EagerGestureRecognizer>(
                                      EagerGestureRecognizer.new,
                                      (_) {},
                                    ),
                                  },
                                  child: Listener(
                                    onPointerDown: _onDown,
                                    onPointerMove: _onMove,
                                    onPointerUp: _onUp,
                                    onPointerCancel: _onUp,
                                    child: _Candidate(
                                      start: _start,
                                      duration: _duration,
                                      label: widget.label,
                                      clash: clashes.isNotEmpty,
                                      active: _grip != null,
                                      resizing: _grip == _Grip.resize,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: _reduced ? Duration.zero : GridMetrics.drawerHeight,
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: clashes.isEmpty && !past
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.lg, 0),
                  child: _Notice(
                    clash: clashes.isEmpty
                        ? null
                        : '${clashes.first.ticket.title} · '
                            '${Clock.span(clashes.first.ticket.startsAt, clashes.first.ticket.durationMinutes)}'
                            '${clashes.length > 1 ? ' +${clashes.length - 1}' : ''}',
                    past: past,
                  ),
                ),
        ),
        DrawerFooter(
          children: [
            DrawerSecondaryButton(
              label: 'Back',
              onTap: MultiViewDrawer.of(context).pop,
            ),
            DrawerPrimaryButton(
              label: '${widget.confirmLabel} · ${DateFormat('EEE').format(_day)} ${Clock.minutes(_start)}',
              onTap: _confirm,
            ),
          ],
        ),
      ],
    );
  }
}

class _Hours extends StatelessWidget {
  const _Hours({required this.scale, required this.highlight, required this.live});

  final TimeScale scale;
  final List<int> highlight;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final style = Type.mono.copyWith(fontSize: 10.5, color: Night.mist);
    bool near(int hour) => live && highlight.any((m) => (m - hour * 60).abs() < 14);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (var h = 1; h < 24; h++)
          if (!near(h))
            Positioned(
              top: scale.px(h * 60) - 7,
              right: Space.sm,
              child: Text(Clock.minutes(h * 60), style: style),
            ),
        if (live)
          for (final minutes in highlight)
            Positioned(
              top: scale.px(minutes) - 9,
              right: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: const BoxDecoration(
                  color: Night.bone,
                  borderRadius: BorderRadius.all(Radius.circular(6)),
                ),
                child: Text(
                  Clock.minutes(minutes.clamp(0, 24 * 60 - 1)),
                  style: Type.monoBold.copyWith(fontSize: 10.5, color: Night.ink),
                ),
              ),
            ),
      ],
    );
  }
}

class _PickerRules extends CustomPainter {
  const _PickerRules({required this.scale, required this.pastUntil});

  final TimeScale scale;
  final int pastUntil;

  @override
  void paint(Canvas canvas, Size size) {
    if (pastUntil > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, scale.px(pastUntil)),
          const Radius.circular(6),
        ),
        Paint()..color = const Color(0x0AFFFFFF),
      );
    }
    final hour = Paint()
      ..color = Night.line
      ..strokeWidth = 1;
    final half = Paint()
      ..color = Night.hairline
      ..strokeWidth = 1;
    for (var h = 0; h <= 24; h++) {
      final y = scale.px(h * 60) + 0.5;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), hour);
      if (h < 24) {
        final hy = scale.px(h * 60 + 30) + 0.5;
        canvas.drawLine(Offset(0, hy), Offset(size.width, hy), half);
      }
    }
  }

  @override
  bool shouldRepaint(_PickerRules old) => old.pastUntil != pastUntil;
}

/// What is already on the day, quiet enough that the candidate leads.
class _Booked extends StatelessWidget {
  const _Booked({super.key, required this.slices, required this.scale});

  final List<DaySlice> slices;
  final TimeScale scale;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          for (final slice in slices)
            Positioned(
              top: scale.px(slice.topMinutes) + 1,
              left: 6,
              right: 0,
              height: math.max(10.0, scale.px(slice.durationMinutes) - 2),
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: Color(0x14FFFFFF),
                  borderRadius: BorderRadius.all(Radius.circular(7)),
                  border: Border.fromBorderSide(BorderSide(color: Color(0x24FFFFFF))),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                  child: LayoutBuilder(
                    builder: (context, constraints) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (constraints.maxHeight >= 14)
                          Text(
                            slice.ticket.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Type.caption.copyWith(
                              fontSize: 11.5,
                              color: Night.bone.withValues(alpha: 0.6),
                            ),
                          ),
                        if (constraints.maxHeight >= 30)
                          Text(
                            Clock.span(slice.ticket.startsAt, slice.ticket.durationMinutes),
                            style: Type.mono.copyWith(fontSize: 10, color: Night.mist),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Candidate extends StatelessWidget {
  const _Candidate({
    required this.start,
    required this.duration,
    required this.label,
    required this.clash,
    required this.active,
    required this.resizing,
  });

  final int start;
  final int duration;
  final String? label;
  final bool clash;
  final bool active;
  final bool resizing;

  @override
  Widget build(BuildContext context) {
    final fill = clash ? Night.caution : Night.bone;
    const text = Night.ink;
    final span = '${Clock.minutes(start)} – ${Clock.minutes((start + duration).clamp(0, 24 * 60))}';
    final hours = duration ~/ 60;
    final minutes = duration % 60;
    final length = hours == 0 ? '$minutes min' : (minutes == 0 ? '$hours h' : '$hours h $minutes');

    return Semantics(
      label: 'Candidate time $span, $length. Drag to move, drag the bottom edge to resize.',
      child: AnimatedScale(
        scale: active ? 1.02 : 1,
        duration: const Duration(milliseconds: 120),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(left: 2),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: const BorderRadius.all(Radius.circular(9)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: active ? 0.45 : 0.3),
                blurRadius: active ? 18 : 8,
                offset: Offset(0, active ? 6 : 2),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final tall = constraints.maxHeight >= 44;
              return Stack(
                children: [
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Space.md),
                      child: Row(
                        crossAxisAlignment:
                            tall ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(top: tall ? 8 : 0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      AppIcon(
                                        clash ? SolarIcons.DangerCircle : SolarIcons.ClockCircle,
                                        size: 14,
                                        color: text,
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          span,
                                          maxLines: 1,
                                          overflow: TextOverflow.fade,
                                          softWrap: false,
                                          style: Type.monoBold.copyWith(fontSize: 12.5, color: text),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (tall)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 3),
                                      child: Text(
                                        label?.trim().isNotEmpty == true ? '${label!.trim()} · $length' : length,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Type.caption.copyWith(
                                          color: text.withValues(alpha: 0.7),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          if (!tall)
                            Text(
                              length,
                              style: Type.caption.copyWith(color: text.withValues(alpha: 0.7)),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 4,
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        width: resizing ? 40 : 28,
                        height: 3,
                        decoration: BoxDecoration(
                          color: text.withValues(alpha: resizing ? 0.7 : 0.3),
                          borderRadius: const BorderRadius.all(Radius.circular(2)),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.clash, required this.past});

  final String? clash;
  final bool past;

  @override
  Widget build(BuildContext context) {
    final color = clash != null ? Night.caution : Night.mist;
    final message = clash != null
        ? 'Overlaps $clash'
        : 'This time has already passed';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm + 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          AppIcon(SolarIcons.DangerCircle, size: 18, color: color),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Type.caption.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
