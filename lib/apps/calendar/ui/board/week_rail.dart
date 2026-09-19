import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:shopping_list/apps/calendar/data/expand/days.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';

/// Seven days, Sunday first. Today is notched — a torn tab, not a pill.
class WeekRail extends StatelessWidget {
  const WeekRail({
    super.key,
    required this.anchor,
    required this.selected,
    required this.onSelected,
    this.hover,
  });

  final DateTime anchor;
  final DateTime selected;
  final DateTime? hover;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    final days = Days.weekOf(anchor);
    final today = Days.startOfDay(DateTime.now());

    return SizedBox(
      height: 72,
      child: Row(
        children: [
          for (final day in days)
            Expanded(
              child: _DayCell(
                day: day,
                selected: Days.isSameDay(day, selected),
                today: Days.isSameDay(day, today),
                hover: hover != null && Days.isSameDay(day, hover!),
                onTap: () {
                  HapticFeedback.selectionClick();
                  onSelected(day);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.selected,
    required this.today,
    required this.hover,
    required this.onTap,
  });

  final DateTime day;
  final bool selected;
  final bool today;
  final bool hover;
  final VoidCallback onTap;

  static const _names = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    final ink = selected || hover ? palette.print : palette.faded;

    return Semantics(
      button: true,
      selected: selected,
      label: '${_names[day.weekday % 7]} ${day.day}',
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _names[day.weekday % 7],
              style: Type.eyebrow.copyWith(color: ink, letterSpacing: 0.8),
            ),
            const SizedBox(height: 4),
            DecoratedBox(
              decoration: BoxDecoration(
                color: today ? palette.carbon.withValues(alpha: 0.12) : null,
                border: selected
                    ? Border(bottom: BorderSide(color: palette.print, width: 2))
                    : hover
                        ? Border(
                            bottom: BorderSide(color: palette.scorch, width: 2),
                          )
                        : null,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Text(
                  '${day.day}',
                  style: Type.monoBold.copyWith(
                    color: ink,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
