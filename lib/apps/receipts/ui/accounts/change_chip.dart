import 'package:flutter/material.dart';

import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/design/widgets/ink_plate.dart';
import 'package:shopping_list/core/util/money.dart';

/// Today's move, as a statement code rather than a coloured sparkline.
///
/// Up means money arrived, down means it left. The percentage is against what
/// the account held at midnight, which is the only baseline a day's change
/// actually has. No second colour: the arrow is the whole signal.
class ChangeChip extends StatelessWidget {
  const ChangeChip({
    super.key,
    required this.deltaMinor,
    required this.balanceMinor,
    this.compact = false,
  });

  final int deltaMinor;
  final int balanceMinor;
  final bool compact;

  /// Share of the midnight balance that moved today, or null when midnight
  /// was zero and a percentage would be a lie.
  static String? percentLabel(int deltaMinor, int balanceMinor) {
    final start = balanceMinor - deltaMinor;
    if (start == 0) return null;
    final pct = (deltaMinor.abs() / start.abs()) * 100;
    if (pct < 0.05) return '0%';
    if (pct < 10) {
      final one = pct.toStringAsFixed(1);
      return one.endsWith('.0') ? '${pct.round()}%' : '$one%';
    }
    return '${pct.round()}%';
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    final up = deltaMinor > 0;
    final flat = deltaMinor == 0;
    final percent = percentLabel(deltaMinor, balanceMinor);
    final label = [
      Money.format(deltaMinor.abs()),
      if (percent != null) percent,
    ].join(' · ');

    return Semantics(
      label: flat
          ? 'No move today'
          : '${up ? 'Up' : 'Down'} $label today',
      child: Material(
        color: palette.paperShade,
        shape: InkPlateBorder(
          borderRadius: Radii.key,
          side: BorderSide(
            color: palette.print.withValues(alpha: 0.28),
            width: 1,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? Space.sm : Space.md,
            vertical: compact ? 5 : 7,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                flat
                    ? Icons.remove
                    : up
                        ? Icons.arrow_upward
                        : Icons.arrow_downward,
                size: compact ? 12 : 14,
                color: palette.print,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: Type.monoBold.copyWith(
                  color: palette.print,
                  fontSize: compact ? 11 : 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
