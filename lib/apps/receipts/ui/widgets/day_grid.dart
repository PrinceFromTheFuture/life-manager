import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';

/// Picking a day of the month, as a month laid out flat.
///
/// A dropdown would need three taps to say "the 10th". This says it in one, in
/// the same square-key language as the register keypad — the whole month is on
/// screen, so choosing is recognition rather than scrolling a list of numbers.
///
/// Shared by the payment method editor (statement day) and the standing order
/// editor (the day a rule runs), which is why it carries its own short-month
/// note rather than leaving each caller to remember it.
class DayGrid extends StatelessWidget {
  const DayGrid({
    super.key,
    required this.selected,
    required this.onSelected,
    this.shortMonthNote,
  });

  final int? selected;
  final ValueChanged<int> onSelected;

  /// Shown only once a day past the 28th is picked. Permanent warnings about
  /// an edge case nobody has hit yet are noise.
  final String? shortMonthNote;

  static const int _columns = 7;
  static const double _cell = 44;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    final note = shortMonthNote;
    final showNote = note != null && selected != null && selected! > 28;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var row = 0; row * _columns < 31; row++)
          Row(
            children: [
              for (var column = 0; column < _columns; column++)
                Expanded(
                  child: () {
                    final day = row * _columns + column + 1;
                    if (day > 31) return const SizedBox(height: _cell);
                    return _DayKey(
                      day: day,
                      selected: day == selected,
                      onTap: () => onSelected(day),
                    );
                  }(),
                ),
            ],
          ),
        if (showNote) ...[
          const SizedBox(height: Space.sm),
          Text(note, style: Type.caption.copyWith(color: palette.faded)),
        ],
      ],
    );
  }
}

class _DayKey extends StatelessWidget {
  const _DayKey({
    required this.day,
    required this.selected,
    required this.onTap,
  });

  final int day;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    final light = Theme.of(context).brightness == Brightness.light;
    final ink = selected ? (light ? palette.paper : palette.print) : palette.print;

    return Semantics(
      button: true,
      selected: selected,
      label: 'Day $day',
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Material(
          color: selected ? palette.carbon : palette.paperShade,
          // Keys are paper, and paper has square corners in this system.
          borderRadius: BorderRadius.zero,
          child: InkWell(
            onTap: () {
              unawaited(HapticFeedback.selectionClick());
              onTap();
            },
            child: SizedBox(
              height: DayGrid._cell - 4,
              child: Center(
                child: Text(
                  '$day',
                  style: Type.mono.copyWith(
                    color: ink,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
