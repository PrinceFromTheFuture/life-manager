import 'package:flutter/material.dart';

import 'package:shopping_list/apps/receipts/data/models/category_ink.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/util/money.dart';

/// Arrival or departure, as a number in ink. No plate, no border — the colour
/// is the whole chip.
class MoveChip extends StatelessWidget {
  const MoveChip({
    super.key,
    required this.amountMinor,
    this.compact = false,
  });

  /// Signed. Positive arrived (pine), negative left (carmine). Zero hides.
  final int amountMinor;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (amountMinor == 0) return const SizedBox.shrink();
    final brightness = Theme.of(context).brightness;
    final arriving = amountMinor > 0;
    final ink = arriving
        ? CategoryInk.pine.of(brightness)
        : CategoryInk.carmine.of(brightness);

    return Semantics(
      label: arriving
          ? 'In ${Money.format(amountMinor)}'
          : 'Out ${Money.format(amountMinor.abs())}',
      child: Text(
        Money.formatSigned(amountMinor),
        style: Type.monoBold.copyWith(
          color: ink,
          fontSize: compact ? 11 : 12,
        ),
      ),
    );
  }
}
