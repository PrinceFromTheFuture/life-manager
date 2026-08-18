import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:shopping_list/apps/receipts/data/models/expense.dart';
import 'package:shopping_list/apps/receipts/data/models/month_kind_totals.dart';
import 'package:shopping_list/apps/receipts/data/receipts_view.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/design/widgets/perforation.dart';
import 'package:shopping_list/core/util/money.dart';

/// A labelled ink run. Square, not pilled — a register prints a block of
/// ink, it does not round the corners of a bar chart.
class InkRun extends StatelessWidget {
  const InkRun({
    super.key,
    required this.label,
    required this.amountMinor,
    required this.fraction,
    this.ink,
    this.detail,
  });

  final String label;
  final int amountMinor;
  final double fraction;
  final Color? ink;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    final fill = ink ?? palette.carbon;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Type.item.copyWith(color: palette.print),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              Money.format(amountMinor),
              style: Type.monoBold.copyWith(color: palette.print),
            ),
          ],
        ),
        if (detail != null) ...[
          const SizedBox(height: 2),
          Text(detail!, style: Type.caption.copyWith(color: palette.faded)),
        ],
        const SizedBox(height: Space.xs),
        LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                Container(
                  height: 8,
                  width: constraints.maxWidth,
                  color: palette.paperShade,
                ),
                AnimatedContainer(
                  duration: Motion.settle,
                  curve: Motion.heat,
                  height: 8,
                  width: constraints.maxWidth * fraction.clamp(0.0, 1.0),
                  color: fill,
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Twelve months as stacked wells. Oldest on the left. Tap a well to open
/// that month. Personal is the lighter fill, business sits on top — the same
/// two inks as the kind breakdown, not a second palette.
class MonthRegister extends StatelessWidget {
  const MonthRegister({
    super.key,
    required this.months,
    required this.selected,
    required this.onSelect,
  });

  /// Oldest first.
  final List<MonthKindTotals> months;
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    final max = months.fold<int>(0, (m, row) => math.max(m, row.totalMinor));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: 'Twelve months of spending.',
          child: SizedBox(
            height: 96,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < months.length; i++) ...[
                  if (i > 0) const SizedBox(width: 3),
                  Expanded(
                    child: _StackedWell(
                      personal: months[i].personalMinor,
                      business: months[i].businessMinor,
                      max: max,
                      selected: months[i].month.year == selected.year &&
                          months[i].month.month == selected.month,
                      onTap: () => onSelect(months[i].month),
                      semantic:
                          '${DateFormat('MMMM yyyy').format(months[i].month)}, ${Money.format(months[i].totalMinor)}',
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
            Text(
              DateFormat('MMM yy').format(months.first.month).toUpperCase(),
              style: Type.mono.copyWith(color: palette.faded, fontSize: 10),
            ),
            const Spacer(),
            Text(
              DateFormat('MMM yy').format(months.last.month).toUpperCase(),
              style: Type.mono.copyWith(color: palette.faded, fontSize: 10),
            ),
          ],
        ),
        const SizedBox(height: Space.sm),
        Text(
          'Personal underneath, business on top. Tap a month to open it.',
          style: Type.caption.copyWith(color: palette.faded),
        ),
      ],
    );
  }
}

/// The five statement weeks of a month, stacked the same way.
class WeekWells extends StatelessWidget {
  const WeekWells({super.key, required this.weeks});

  final List<StatementWeek> weeks;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    final max = weeks.fold<int>(0, (m, w) => math.max(m, w.amountMinor));
    if (max == 0) {
      return Text(
        'No spend to plot yet.',
        style: Type.caption.copyWith(color: palette.faded),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 88,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < weeks.length; i++) ...[
                if (i > 0) const SizedBox(width: Space.sm),
                Expanded(
                  child: _StackedWell(
                    personal: weeks[i].personalMinor,
                    business: weeks[i].businessMinor,
                    max: max,
                    selected: false,
                    maxHeight: 88,
                    semantic:
                        'Days ${weeks[i].fromDay}–${weeks[i].toDay}, ${Money.format(weeks[i].amountMinor)}',
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (var i = 0; i < weeks.length; i++) ...[
              if (i > 0) const SizedBox(width: Space.sm),
              Expanded(
                child: Text(
                  '${weeks[i].fromDay}–${weeks[i].toDay}',
                  textAlign: TextAlign.center,
                  style: Type.mono.copyWith(color: palette.faded, fontSize: 10),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _StackedWell extends StatelessWidget {
  const _StackedWell({
    required this.personal,
    required this.business,
    required this.max,
    required this.selected,
    required this.semantic,
    this.onTap,
    this.maxHeight = 96,
  });

  final int personal;
  final int business;
  final int max;
  final bool selected;
  final String semantic;
  final VoidCallback? onTap;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    final total = personal + business;
    final height = max == 0 || total == 0
        ? 3.0
        : (maxHeight * total / max).clamp(4.0, maxHeight);
    final personalH =
        total == 0 ? 0.0 : height * personal / total;
    final businessH = height - personalH;

    final well = Semantics(
      button: onTap != null,
      label: semantic,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? palette.print : palette.perforation,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: SizedBox(
            height: height,
            width: double.infinity,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (businessH > 0)
                  Container(
                    height: businessH,
                    width: double.infinity,
                    color: palette.carbon,
                  ),
                if (personalH > 0)
                  Container(
                    height: personalH,
                    width: double.infinity,
                    color: palette.carbon.withValues(alpha: 0.45),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    if (onTap == null) return well;
    return GestureDetector(onTap: onTap, child: well);
  }
}

/// One column per day. Personal and business share the column so a mixed
/// day prints as two inks, not a single anonymous total.
///
/// Tap or drag to pin a day. The callout is a small slip sitting on the
/// tape — date, total, and the expenses themselves — because a figure
/// under the chart is not enough to read a day.
class StackedDailySpend extends StatefulWidget {
  const StackedDailySpend({
    super.key,
    required this.month,
    required this.days,
    required this.expenses,
    this.onOpenExpense,
  });

  final DateTime month;
  final List<DayKindSpend> days;
  final List<Expense> expenses;
  final ValueChanged<Expense>? onOpenExpense;

  @override
  State<StackedDailySpend> createState() => _StackedDailySpendState();
}

class _StackedDailySpendState extends State<StackedDailySpend> {
  int? _selectedDay;

  @override
  void didUpdateWidget(StackedDailySpend old) {
    super.didUpdateWidget(old);
    if (old.month != widget.month) {
      _selectedDay = null;
    }
  }

  void _pickDay(double dx, double width, {required bool toggle}) {
    if (widget.days.isEmpty || width <= 0) return;
    final index = (dx / width * widget.days.length)
        .floor()
        .clamp(0, widget.days.length - 1);
    final day = widget.days[index].day;
    if (toggle && _selectedDay == day) {
      setState(() => _selectedDay = null);
      return;
    }
    if (_selectedDay == day) return;
    HapticFeedback.selectionClick();
    setState(() => _selectedDay = day);
  }

  List<Expense> _slipsOn(int day) {
    final slips = [
      for (final e in widget.expenses)
        if (e.occurredAt.toLocal().day == day) e,
    ];
    slips.sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
    return slips;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    final max = widget.days.fold<int>(0, (m, d) => math.max(m, d.totalMinor));
    final selected = _selectedDay;
    final picked = selected == null
        ? null
        : widget.days.firstWhere((d) => d.day == selected);
    final slips = selected == null ? const <Expense>[] : _slipsOn(selected);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final calloutWidth = math.min(240.0, math.max(168.0, width * 0.62));
        final n = widget.days.length;
        final selectedCenter = selected == null || n == 0
            ? 0.0
            : ((selected - 0.5) / n) * width;
        final calloutLeft = selected == null
            ? 0.0
            : (selectedCenter - calloutWidth / 2)
                .clamp(0.0, math.max(0.0, width - calloutWidth))
                .toDouble();
        final caretDx = selected == null
            ? calloutWidth / 2
            : (selectedCenter - calloutLeft).clamp(12.0, calloutWidth - 12)
                .toDouble();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedSize(
              duration: Motion.settle,
              curve: Motion.heat,
              alignment: Alignment.topCenter,
              child: picked == null
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(bottom: Space.sm),
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Padding(
                          padding: EdgeInsets.only(left: calloutLeft.toDouble()),
                          child: SizedBox(
                            width: calloutWidth,
                            child: _DayCallout(
                              month: widget.month,
                              day: picked,
                              slips: slips,
                              caretDx: caretDx,
                              onOpenExpense: widget.onOpenExpense,
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
            SizedBox(
              height: 120,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (details) => _pickDay(
                  details.localPosition.dx,
                  width,
                  toggle: true,
                ),
                onHorizontalDragUpdate: (details) => _pickDay(
                  details.localPosition.dx,
                  width,
                  toggle: false,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final day in widget.days)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 1),
                          child: Semantics(
                            button: true,
                            selected: selected == day.day,
                            label:
                                'Day ${day.day}, ${Money.format(day.totalMinor)}',
                            child: _DayStack(
                              personal: day.personalMinor,
                              business: day.businessMinor,
                              max: max,
                              selected: selected == day.day,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: Space.xs),
            Container(height: 1, color: palette.perforation),
            const SizedBox(height: Space.sm),
            Text(
              picked == null
                  ? 'Tap a day — drag to walk the month.'
                  : DateFormat('EEEE d MMMM').format(
                      DateTime(widget.month.year, widget.month.month, picked.day),
                    ),
              style: Type.caption.copyWith(color: palette.faded),
            ),
          ],
        );
      },
    );
  }
}

/// The day's tape, parked above the column it describes. A floating
/// tooltip would clip on the first and last days; this slip is clamped
/// to the chart and points at the selected bar.
class _DayCallout extends StatelessWidget {
  const _DayCallout({
    required this.month,
    required this.day,
    required this.slips,
    required this.caretDx,
    this.onOpenExpense,
  });

  final DateTime month;
  final DayKindSpend day;
  final List<Expense> slips;
  final double caretDx;
  final ValueChanged<Expense>? onOpenExpense;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    final date = DateTime(month.year, month.month, day.day);
    final visible = slips.take(4).toList();
    final extra = slips.length - visible.length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: palette.paper,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: palette.print),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.md,
                Space.sm,
                Space.md,
                Space.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('EEE d MMM').format(date).toUpperCase(),
                    style: Type.eyebrow.copyWith(color: palette.faded),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    Money.format(day.totalMinor),
                    style: Type.monoBold.copyWith(color: palette.print),
                  ),
                  if (day.businessMinor > 0 && day.personalMinor > 0) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${Money.format(day.businessMinor)} to claim · ${Money.format(day.personalMinor)} personal',
                      style: Type.caption.copyWith(color: palette.faded),
                    ),
                  ],
                  const SizedBox(height: Space.sm),
                  const PerforatedRule(),
                  const SizedBox(height: Space.sm),
                  if (slips.isEmpty)
                    Text(
                      'Nothing spent.',
                      style: Type.caption.copyWith(color: palette.faded),
                    )
                  else ...[
                    for (final slip in visible)
                      _CalloutSlip(
                        expense: slip,
                        onTap: onOpenExpense == null
                            ? null
                            : () => onOpenExpense!(slip),
                      ),
                    if (extra > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          extra == 1 ? '1 more slip' : '$extra more slips',
                          style: Type.caption.copyWith(color: palette.faded),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
        SizedBox(
          height: 8,
          width: double.infinity,
          child: CustomPaint(
            painter: _CaretPainter(
              x: caretDx,
              color: palette.print,
              fill: palette.paper,
            ),
          ),
        ),
      ],
    );
  }
}

class _CalloutSlip extends StatelessWidget {
  const _CalloutSlip({required this.expense, this.onTap});

  final Expense expense;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              expense.isBusiness ? '${expense.title} · claim' : expense.title,
              style: Type.caption.copyWith(color: palette.print),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: Space.sm),
          Text(
            expense.amountLabel,
            style: Type.mono.copyWith(color: palette.print, fontSize: 12),
          ),
        ],
      ),
    );
    if (onTap == null) return row;
    return InkWell(onTap: onTap, child: row);
  }
}

class _CaretPainter extends CustomPainter {
  _CaretPainter({required this.x, required this.color, required this.fill});

  final double x;
  final Color color;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    final tip = Offset(x, size.height);
    final path = Path()
      ..moveTo(x - 6, 0)
      ..lineTo(x + 6, 0)
      ..lineTo(tip.dx, tip.dy)
      ..close();
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..strokeJoin = StrokeJoin.miter,
    );
    // Cover the slip's bottom rule so the caret reads as part of it.
    canvas.drawLine(
      Offset(x - 5, 0),
      Offset(x + 5, 0),
      Paint()
        ..color = fill
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _CaretPainter old) =>
      old.x != x || old.color != color || old.fill != fill;
}

class _DayStack extends StatelessWidget {
  const _DayStack({
    required this.personal,
    required this.business,
    required this.max,
    required this.selected,
  });

  final int personal;
  final int business;
  final int max;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    final total = personal + business;
    final height = total == 0 || max == 0
        ? 2.0
        : (116.0 * total / max).clamp(4.0, 116.0);
    final personalH = total == 0 ? 0.0 : height * personal / total;
    final businessH = height - personalH;

    return Align(
      alignment: Alignment.bottomCenter,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: selected
              ? Border(
                  left: BorderSide(color: palette.print, width: 1),
                  right: BorderSide(color: palette.print, width: 1),
                )
              : null,
        ),
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (businessH > 0)
                Container(
                  height: businessH,
                  width: double.infinity,
                  color: palette.carbon,
                ),
              if (personalH > 0)
                Container(
                  height: personalH,
                  width: double.infinity,
                  color: palette.carbon.withValues(alpha: 0.45),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
