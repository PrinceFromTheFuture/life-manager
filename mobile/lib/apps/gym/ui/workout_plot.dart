import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import 'package:shopping_list/apps/gym/data/models/progress.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/util/load.dart';

/// Top sets across workouts, plotted by session rather than by calendar.
///
/// A missed week is not a flat line — the next stamp is the next workout.
/// Dots are the gym stamp at rest; the PR is a double ring. The line is ink,
/// not a filled area, so it does not read as a generic dashboard chart.
class WorkoutPlot extends StatelessWidget {
  const WorkoutPlot({
    super.key,
    required this.marks,
    this.selectedIndex,
    this.onSelect,
    this.height = 72,
    this.compact = true,
  });

  final List<WorkoutMark> marks;
  final int? selectedIndex;
  final ValueChanged<int>? onSelect;

  final double height;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    final byReps = WorkoutMark.plotByReps(marks);
    final values = [
      for (final m in marks) m.plotValue(byReps: byReps),
    ];

    return Semantics(
      label: _semantic(byReps),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: GestureDetector(
          onTapDown: onSelect == null || marks.isEmpty
              ? null
              : (details) {
                  final box = context.findRenderObject() as RenderBox?;
                  if (box == null) return;
                  onSelect!(
                    _indexAt(
                      details.localPosition,
                      box.size,
                      marks.length,
                      compact: compact,
                    ),
                  );
                },
          child: CustomPaint(
            painter: _PlotPainter(
              values: values,
              dates: [for (final m in marks) m.day],
              byReps: byReps,
              selectedIndex: selectedIndex,
              compact: compact,
              print: palette.print,
              faded: palette.faded,
              carbon: palette.carbon,
              perforation: palette.perforation,
            ),
          ),
        ),
      ),
    );
  }

  String _semantic(bool byReps) {
    if (marks.isEmpty) return 'No workouts yet.';
    if (marks.length == 1) {
      return byReps
          ? 'One workout, ${marks.single.topReps} reps.'
          : 'One workout, ${Load.format(marks.single.topWeightG)}.';
    }
    final first = marks.first;
    final last = marks.last;
    return byReps
        ? '${marks.length} workouts, ${first.topReps} to ${last.topReps} reps.'
        : '${marks.length} workouts, ${Load.format(first.topWeightG)} to ${Load.format(last.topWeightG)}.';
  }

  static int _indexAt(
    Offset local,
    Size size,
    int count, {
    required bool compact,
  }) {
    if (count <= 1) return 0;
    final plot = _PlotPainter.plotRect(size, compact: compact);
    if (plot.width <= 0) return count - 1;
    final t = ((local.dx - plot.left) / plot.width).clamp(0.0, 1.0);
    return (t * (count - 1)).round();
  }
}

class _PlotPainter extends CustomPainter {
  _PlotPainter({
    required this.values,
    required this.dates,
    required this.byReps,
    required this.selectedIndex,
    required this.compact,
    required this.print,
    required this.faded,
    required this.carbon,
    required this.perforation,
  });

  final List<int> values;
  final List<DateTime> dates;
  final bool byReps;
  final int? selectedIndex;
  final bool compact;
  final Color print;
  final Color faded;
  final Color carbon;
  final Color perforation;

  static const double _gutter = 36;
  static const double _bottom = 18;

  static Rect plotRect(Size size, {required bool compact}) {
    final left = compact ? 8.0 : _gutter;
    final right = size.width - 8;
    final top = 10.0;
    final bottom = size.height - (compact ? 8 : _bottom);
    return Rect.fromLTRB(left, top, right, bottom);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final plot = plotRect(size, compact: compact);
    if (plot.width <= 0 || plot.height <= 0) return;

    var minV = values.first;
    var maxV = values.first;
    var prIndex = 0;
    for (var i = 0; i < values.length; i++) {
      if (values[i] < minV) minV = values[i];
      if (values[i] >= maxV) {
        maxV = values[i];
        prIndex = i;
      }
    }

    // Zoom to the working range so 80 → 85 is a climb, not a hairline at
    // the top of a zero-based chart.
    var lo = minV.toDouble();
    var hi = maxV.toDouble();
    if (hi <= lo) {
      lo = math.max(0, lo - (byReps ? 2 : 2500));
      hi = hi + (byReps ? 2 : 2500);
    } else {
      final pad = (hi - lo) * 0.16;
      lo = math.max(0, lo - pad);
      hi += pad;
    }
    final span = hi - lo;

    Offset point(int i) {
      final t = values.length == 1 ? 0.5 : i / (values.length - 1);
      final y = plot.bottom - ((values[i] - lo) / span) * plot.height;
      return Offset(plot.left + t * plot.width, y);
    }

    final points = [for (var i = 0; i < values.length; i++) point(i)];

    // PR as a perforated guide — the same dots as a receipt rule.
    final prY = points[prIndex].dy;
    final rule = Paint()..color = perforation;
    for (var x = plot.left; x < plot.right; x += 5) {
      canvas.drawCircle(Offset(x, prY), 0.8, rule);
    }

    if (points.length >= 2) {
      final line = Paint()
        ..color = carbon
        ..style = PaintingStyle.stroke
        ..strokeWidth = compact ? 1.4 : 1.8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (var i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
      canvas.drawPath(path, line);
    }

    for (var i = 0; i < points.length; i++) {
      final isPr = i == prIndex;
      final isLast = i == points.length - 1;
      final isSelected = selectedIndex == i;
      final r = compact
          ? (isSelected || isLast ? 3.4 : 2.6)
          : (isSelected || isLast ? 5.0 : 3.8);
      canvas.drawCircle(
        points[i],
        r,
        Paint()..color = isLast || isSelected ? carbon : print,
      );
      if (isPr) {
        canvas.drawCircle(
          points[i],
          r + (compact ? 2.5 : 3.5),
          Paint()
            ..color = carbon
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2,
        );
      }
    }

    if (!compact) {
      _label(
        canvas,
        _format(maxV, byReps),
        Offset(0, plot.top - 2),
        faded,
      );
      if (minV != maxV) {
        _label(
          canvas,
          _format(minV, byReps),
          Offset(0, plot.bottom - 10),
          faded,
        );
      }
      _label(
        canvas,
        DateFormat('d MMM').format(dates.first),
        Offset(plot.left, plot.bottom + 2),
        faded,
      );
      if (dates.length > 1) {
        final text = DateFormat('d MMM').format(dates.last);
        _label(
          canvas,
          text,
          Offset(plot.right - 48, plot.bottom + 2),
          faded,
          alignEnd: true,
          width: 48,
        );
      }
    }
  }

  String _format(int value, bool byReps) {
    if (byReps) return '$value';
    if (value == 0) return '0';
    return Load.formatBare(value);
  }

  void _label(
    Canvas canvas,
    String text,
    Offset offset,
    Color color, {
    bool alignEnd = false,
    double width = _gutter,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: Type.mono.copyWith(color: color, fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: width);
    final dx = alignEnd ? offset.dx + width - tp.width : offset.dx;
    tp.paint(canvas, Offset(dx, offset.dy));
  }

  @override
  bool shouldRepaint(covariant _PlotPainter old) =>
      old.values != values ||
      old.selectedIndex != selectedIndex ||
      old.carbon != carbon ||
      old.compact != compact;
}
