import 'package:flutter/widgets.dart';

import 'package:shopping_list/apps/calendar/data/expand/days.dart';
import 'package:shopping_list/apps/calendar/ui/grid/grid_metrics.dart';

/// Where the incoming week's columns rest once it slides in.
enum Landing {
  /// Sunday at the left edge. Paging forward lands here, so a pull off
  /// Saturday reads as one continuous strip of days.
  start,

  /// Saturday at the right edge. Paging back lands here.
  end,

  /// The same columns as the week that left, a week later or earlier.
  keep,

  /// [WeekNav.landingDay] at the left edge, as far as the week allows.
  day,
}

/// The days the grid currently shows, in columns from Sunday.
@immutable
class Lens {
  const Lens({required this.start, required this.span});

  final double start;
  final double span;

  /// Index of the leftmost column more than half in view.
  int get firstDay => (start + 0.5).floor().clamp(0, 6);

  bool shows(int index) => index + 1 > start + 0.05 && index < start + span - 0.05;

  @override
  bool operator ==(Object other) =>
      other is Lens && other.start == start && other.span == span;

  @override
  int get hashCode => Object.hash(start, span);
}

/// One week state for the strip, the grid and the top bar.
///
/// The grid and the strip both animate from [progress]; neither owns the
/// week. Whoever asks for a change — an edge pull, a strip swipe, Today, a
/// date in the month view — goes through [go], and both surfaces move in the
/// same frame.
class WeekNav extends ChangeNotifier {
  WeekNav({required TickerProvider vsync, required DateTime week})
      : _week = Days.startOfWeek(week),
        slide = AnimationController(
          vsync: vsync,
          duration: GridMetrics.weekSlide,
          value: 1,
        ) {
    progress = CurvedAnimation(parent: slide, curve: GridMetrics.ease);
    slide.addStatusListener((status) {
      if (status == AnimationStatus.completed && _outgoing != null) {
        _outgoing = null;
        notifyListeners();
      }
    });
  }

  DateTime _week;
  DateTime? _outgoing;
  int _direction = 1;
  Landing _landing = Landing.keep;
  DateTime? _landingDay;
  ({DateTime at, bool time})? _reveal;
  int _serial = 0;

  final AnimationController slide;
  late final Animation<double> progress;

  /// Live position of the grid's columns. The strip draws its lens from it.
  final ValueNotifier<Lens> lens = ValueNotifier(
    const Lens(start: 0, span: GridMetrics.defaultDensity),
  );

  /// Sunday of the week on screen, or arriving.
  DateTime get week => _week;

  /// The week sliding out, while a transition runs.
  DateTime? get outgoing => _outgoing;

  /// +1 when the new week is later, -1 when earlier.
  int get direction => _direction;

  Landing get landing => _landing;

  DateTime? get landingDay => _landingDay;

  /// Bumped on every week change, so listeners can tell two visits to the
  /// same week apart.
  int get serial => _serial;

  bool get transitioning => _outgoing != null;

  List<DateTime> get days => Days.weekOf(_week);

  void go(
    DateTime target, {
    Landing landing = Landing.keep,
    DateTime? day,
    bool animate = true,
  }) {
    final next = Days.startOfWeek(target);
    if (next == _week) {
      if (day != null) reveal(day);
      return;
    }
    _direction = next.isAfter(_week) ? 1 : -1;
    _outgoing = animate ? _week : null;
    _week = next;
    _landing = landing;
    _landingDay = day;
    _serial++;
    if (animate) {
      slide.forward(from: 0);
    } else {
      slide.value = 1;
    }
    notifyListeners();
  }

  /// One week later ([direction] 1) or earlier (-1).
  void step(int direction, {Landing landing = Landing.keep, bool animate = true}) {
    go(Days.addDays(_week, 7 * direction), landing: landing, animate: animate);
  }

  /// Bring [at]'s day into view, switching week if needed. With [time] the
  /// grid also scrolls to that hour.
  void reveal(DateTime at, {bool time = false, bool animate = true}) {
    final target = Days.startOfWeek(at);
    _reveal = (at: at, time: time);
    if (target != _week) {
      go(target, landing: Landing.day, day: at, animate: animate);
      return;
    }
    notifyListeners();
  }

  /// The pending reveal, consumed once by the grid.
  ({DateTime at, bool time})? takeReveal() {
    final out = _reveal;
    _reveal = null;
    return out;
  }

  @override
  void dispose() {
    slide.dispose();
    lens.dispose();
    super.dispose();
  }
}
