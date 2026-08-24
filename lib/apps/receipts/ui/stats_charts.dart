import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' hide TextDirection;

import 'package:shopping_list/apps/receipts/data/finance/calendar.dart';
import 'package:shopping_list/apps/receipts/data/receipts_view.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/util/money.dart';

/// One well per day, stacked in category ink — the gym's week punches, filled
/// with the stamp pads that filed the slips.
///
/// A quiet day is an empty well, not a missing column. Tap to pin a day;
/// the list below the chart is what actually reads it. Horizontal swipe
/// belongs to the period, not to the wells.
class DaySpendChart extends StatelessWidget {
  const DaySpendChart({
    super.key,
    required this.days,
    required this.inks,
    required this.grain,
    this.selected,
    this.onSelect,
  });

  final List<DayCategorySpend> days;
  final Map<int?, Color> inks;
  final StatsGrain grain;
  final DateTime? selected;
  final void Function(DateTime day, {required bool toggle})? onSelect;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    final max = days.fold<int>(0, (m, d) => math.max(m, d.totalMinor));
    final selectedDay = selected;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return Column(
          children: [
            SizedBox(
              height: 128,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: onSelect == null
                    ? null
                    : (details) => _pick(
                          details.localPosition.dx,
                          width,
                          toggle: true,
                        ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < days.length; i++) ...[
                      if (i > 0)
                        SizedBox(
                          width: grain == StatsGrain.week ? Space.xs : 2,
                        ),
                      Expanded(
                        child: Semantics(
                          button: true,
                          selected: selectedDay != null &&
                              Calendar.isSameDay(selectedDay, days[i].day),
                          label:
                              '${DateFormat('EEEE d MMM').format(days[i].day)}, ${Money.format(days[i].totalMinor)}',
                          child: _DayWell(
                            spend: days[i],
                            inks: inks,
                            max: max,
                            selected: selectedDay != null &&
                                Calendar.isSameDay(selectedDay, days[i].day),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                for (var i = 0; i < days.length; i++) ...[
                  if (i > 0)
                    SizedBox(width: grain == StatsGrain.week ? Space.xs : 2),
                  Expanded(
                    child: Text(
                      _label(days[i].day, grain),
                      textAlign: TextAlign.center,
                      style: Type.mono.copyWith(
                        color: selectedDay != null &&
                                Calendar.isSameDay(selectedDay, days[i].day)
                            ? palette.print
                            : palette.faded,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        );
      },
    );
  }

  void _pick(double dx, double width, {required bool toggle}) {
    if (onSelect == null || days.isEmpty || width <= 0) return;
    final index = (dx / width * days.length).floor().clamp(0, days.length - 1);
    final day = days[index].day;
    if (!toggle &&
        selected != null &&
        Calendar.isSameDay(selected!, day)) {
      return;
    }
    HapticFeedback.selectionClick();
    onSelect!(day, toggle: toggle);
  }

  static String _label(DateTime day, StatsGrain grain) {
    if (grain == StatsGrain.week) {
      const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
      return letters[day.weekday - DateTime.monday];
    }
    return '${day.day}';
  }
}

class _DayWell extends StatelessWidget {
  const _DayWell({
    required this.spend,
    required this.inks,
    required this.max,
    required this.selected,
  });

  final DayCategorySpend spend;
  final Map<int?, Color> inks;
  final int max;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    const chartH = 124.0;
    final height = spend.totalMinor == 0 || max == 0
        ? 3.0
        : (chartH * spend.totalMinor / max).clamp(4.0, chartH);

    return Align(
      alignment: Alignment.bottomCenter,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: spend.totalMinor == 0 ? palette.paperShade : null,
          border: Border.all(
            color: selected
                ? palette.print
                : spend.totalMinor == 0
                    ? palette.perforation
                    : palette.print.withValues(alpha: 0.18),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: spend.totalMinor == 0
              ? const SizedBox.expand()
              : Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    for (final slice in spend.slices.reversed)
                      Flexible(
                        flex: slice.amountMinor,
                        child: ColoredBox(
                          color: inks[slice.categoryId] ?? palette.faded,
                          child: const SizedBox.expand(),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// One category's take on the ring. The hole is the selected pad.
class DonutSlice {
  const DonutSlice({
    required this.categoryId,
    required this.name,
    required this.amountMinor,
    required this.ink,
  });

  final int? categoryId;
  final String name;
  final int amountMinor;
  final Color ink;
}

/// A stamp pad seen from above: thick inks around a hole that names the
/// pad you pressed. Not a dashboard pie — the hole is the point.
class CategoryDonut extends StatelessWidget {
  const CategoryDonut({
    super.key,
    required this.slices,
    required this.totalMinor,
    this.selectedId,
    this.onSelect,
    this.onOpen,
  });

  final List<DonutSlice> slices;
  final int totalMinor;
  final int? selectedId;
  final ValueChanged<int?>? onSelect;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    final selected = _selected;
    final centerName = selected?.name ?? 'All';
    final centerAmount = selected?.amountMinor ?? totalMinor;

    return SizedBox(
      height: 196,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return GestureDetector(
            onTapUp: (onSelect == null && onOpen == null)
                ? null
                : (details) => _onTap(details.localPosition, constraints.biggest),
            child: CustomPaint(
              painter: _DonutPainter(
                slices: slices,
                selectedId: selectedId,
                perforation: palette.perforation,
                paper: palette.paper,
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        centerName.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: Type.eyebrow.copyWith(color: palette.faded),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        Money.format(centerAmount),
                        textAlign: TextAlign.center,
                        style: Type.monoBold.copyWith(
                          color: palette.print,
                          fontSize: 18,
                        ),
                      ),
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

  DonutSlice? get _selected {
    if (slices.isEmpty) return null;
    for (final slice in slices) {
      if (slice.categoryId == selectedId) return slice;
    }
    return slices.first;
  }

  void _onTap(Offset local, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final delta = local - center;
    final radius = math.min(size.width, size.height) / 2;
    const stroke = 28.0;
    final outer = radius - 8;
    final ringR = outer - stroke / 2;
    final distance = delta.distance;
    if (distance < ringR - stroke / 2 - 4) {
      onOpen?.call();
      return;
    }
    if (distance > outer || onSelect == null || slices.isEmpty) return;

    var angle = math.atan2(delta.dy, delta.dx) + math.pi / 2;
    if (angle < 0) angle += math.pi * 2;
    final total = slices.fold<int>(0, (sum, s) => sum + s.amountMinor);
    if (total == 0) return;
    var acc = 0.0;
    for (final slice in slices) {
      acc += slice.amountMinor / total * math.pi * 2;
      if (angle <= acc) {
        HapticFeedback.selectionClick();
        onSelect!(slice.categoryId);
        return;
      }
    }
    HapticFeedback.selectionClick();
    onSelect!(slices.last.categoryId);
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.slices,
    required this.selectedId,
    required this.perforation,
    required this.paper,
  });

  final List<DonutSlice> slices;
  final int? selectedId;
  final Color perforation;
  final Color paper;

  static const double _stroke = 28;
  static const double _gap = 0.04;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outer = math.min(size.width, size.height) / 2 - 8;
    final ringR = outer - _stroke / 2;
    final rect = Rect.fromCircle(center: center, radius: ringR);

    if (slices.isEmpty || slices.every((s) => s.amountMinor == 0)) {
      canvas.drawCircle(
        center,
        ringR,
        Paint()
          ..color = perforation
          ..style = PaintingStyle.stroke
          ..strokeWidth = _stroke
          ..strokeCap = StrokeCap.butt,
      );
      return;
    }

    final total = slices.fold<int>(0, (sum, s) => sum + s.amountMinor);
    if (total == 0) return;

    var angle = -math.pi / 2;
    final gap = slices.length == 1 ? 0.0 : _gap;

    for (final slice in slices) {
      final sweep = (slice.amountMinor / total) * math.pi * 2;
      final drawn = math.max(0.0, sweep - gap);
      final selected = slice.categoryId == selectedId;
      canvas.drawArc(
        rect,
        angle + gap / 2,
        drawn,
        false,
        Paint()
          ..color = slice.ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = selected ? _stroke + 3 : _stroke
          ..strokeCap = StrokeCap.butt,
      );
      angle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.slices != slices ||
      old.selectedId != selectedId ||
      old.perforation != perforation;
}

/// Daily take as a line of ink — the gym's session plot, standing on a
/// calendar instead of a session count. Quiet days sit on the baseline.
class SpendPlot extends StatelessWidget {
  const SpendPlot({
    super.key,
    required this.values,
    required this.ink,
    this.dates,
    this.selectedIndex,
    this.onSelect,
    this.height = 64,
    this.compact = true,
  });

  final List<int> values;
  final Color ink;
  final List<DateTime>? dates;
  final int? selectedIndex;
  final ValueChanged<int>? onSelect;
  final double height;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    return Semantics(
      label: _semantic(),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: GestureDetector(
          onTapDown: onSelect == null || values.isEmpty
              ? null
              : (details) {
                  final box = context.findRenderObject() as RenderBox?;
                  if (box == null) return;
                  onSelect!(
                    _indexAt(details.localPosition, box.size, values.length),
                  );
                },
          child: CustomPaint(
            painter: _SpendPainter(
              values: values,
              dates: dates ?? const [],
              selectedIndex: selectedIndex,
              compact: compact,
              ink: ink,
              print: palette.print,
              faded: palette.faded,
              perforation: palette.perforation,
            ),
          ),
        ),
      ),
    );
  }

  String _semantic() {
    if (values.isEmpty) return 'No spend to plot.';
    final spent = values.where((v) => v > 0).length;
    return '$spent ${spent == 1 ? 'day' : 'days'} with spend, ${Money.format(values.fold(0, (a, b) => a + b))} in all.';
  }

  static int _indexAt(Offset local, Size size, int count) {
    if (count <= 1) return 0;
    final plot = _SpendPainter.plotRect(size, compact: true);
    if (plot.width <= 0) return count - 1;
    final t = ((local.dx - plot.left) / plot.width).clamp(0.0, 1.0);
    return (t * (count - 1)).round();
  }
}

class _SpendPainter extends CustomPainter {
  _SpendPainter({
    required this.values,
    required this.dates,
    required this.selectedIndex,
    required this.compact,
    required this.ink,
    required this.print,
    required this.faded,
    required this.perforation,
  });

  final List<int> values;
  final List<DateTime> dates;
  final int? selectedIndex;
  final bool compact;
  final Color ink;
  final Color print;
  final Color faded;
  final Color perforation;

  static const double _gutter = 36;
  static const double _bottom = 18;

  static Rect plotRect(Size size, {required bool compact}) {
    final left = compact ? 8.0 : _gutter;
    final right = size.width - 8;
    const top = 10.0;
    final bottom = size.height - (compact ? 8 : _bottom);
    return Rect.fromLTRB(left, top, right, bottom);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final plot = plotRect(size, compact: compact);
    if (plot.width <= 0 || plot.height <= 0) return;

    var maxV = 0;
    var peak = 0;
    for (var i = 0; i < values.length; i++) {
      if (values[i] >= maxV) {
        maxV = values[i];
        peak = i;
      }
    }

    // Money is zero-based: a ₪400 day should read as tall, not as a zoomed
    // working range the way a gym load plot does.
    final hi = maxV == 0 ? 100.0 : maxV * 1.12;
    final span = hi;

    Offset point(int i) {
      final t = values.length == 1 ? 0.5 : i / (values.length - 1);
      final y = plot.bottom - (values[i] / span) * plot.height;
      return Offset(plot.left + t * plot.width, y);
    }

    final points = [for (var i = 0; i < values.length; i++) point(i)];

    final rule = Paint()..color = perforation;
    for (var x = plot.left; x < plot.right; x += 5) {
      canvas.drawCircle(Offset(x, points[peak].dy), 0.8, rule);
    }

    if (points.length >= 2) {
      final line = Paint()
        ..color = ink
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

    final many = values.length > 14;
    for (var i = 0; i < points.length; i++) {
      final isLast = i == points.length - 1;
      final isSelected = selectedIndex == i;
      final spent = values[i] > 0;
      if (!spent && !isSelected) continue;
      final r = compact
          ? (isSelected || isLast ? 3.4 : (many ? 1.8 : 2.6))
          : (isSelected || isLast ? 5.0 : 3.8);
      canvas.drawCircle(
        points[i],
        r,
        Paint()..color = isLast || isSelected ? ink : print,
      );
      if (isSelected) {
        canvas.drawCircle(
          points[i],
          r + (compact ? 2.5 : 3.5),
          Paint()
            ..color = ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2,
        );
      }
    }

    if (!compact) {
      _label(canvas, _axis(maxV), Offset(0, plot.top - 2), faded);
      _label(canvas, '0', Offset(0, plot.bottom - 10), faded);
      if (dates.isNotEmpty) {
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
  }

  String _axis(int agorot) {
    if (agorot == 0) return '0';
    return '${(agorot / 100).round()}';
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
  bool shouldRepaint(covariant _SpendPainter old) =>
      old.values != values ||
      old.selectedIndex != selectedIndex ||
      old.ink != ink ||
      old.compact != compact;
}
