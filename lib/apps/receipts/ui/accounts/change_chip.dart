import 'package:flutter/material.dart';

import 'package:shopping_list/apps/receipts/data/models/category_ink.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/util/money.dart';

/// Today's move, as a signed number in arrival or departure ink.
///
/// No plate. The colour is the signal: pine arrived, carmine left.
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
    final brightness = Theme.of(context).brightness;
    final up = deltaMinor > 0;
    final flat = deltaMinor == 0;
    final ink = flat
        ? palette.faded
        : up
            ? CategoryInk.pine.of(brightness)
            : CategoryInk.carmine.of(brightness);
    final percent = percentLabel(deltaMinor, balanceMinor);
    final label = [
      Money.formatSigned(deltaMinor),
      if (percent != null) percent,
    ].join(' · ');

    return Semantics(
      label: flat
          ? 'No move today'
          : '${up ? 'Up' : 'Down'} $label today',
      child: Text(
        flat ? 'No move today' : label,
        style: Type.monoBold.copyWith(
          color: ink,
          fontSize: compact ? 11 : 12,
        ),
      ),
    );
  }
}
