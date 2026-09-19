import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/design/widgets/ink_plate.dart';

/// A compact selectable plate for the receipts ledger.
///
/// Filter and sort rows use these so the list stays in the same hardware
/// language as Add expense, instead of growing a chip vocabulary.
class LedgerPlate extends StatelessWidget {
  const LedgerPlate({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    final light = Theme.of(context).brightness == Brightness.light;
    final onInk = light ? palette.paper : palette.print;
    final fill = selected ? palette.carbon : palette.paperShade;
    final edge = selected
        ? Plate.edge(palette)
        : palette.print.withValues(alpha: 0.35);
    final ink = selected ? onInk : palette.print;

    return Material(
      color: fill,
      shape: InkPlateBorder(
        borderRadius: Radii.key,
        side: BorderSide(color: edge, width: 1.25),
        insetColor: selected ? Plate.inset(onInk) : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          unawaited(HapticFeedback.selectionClick());
          onTap();
        },
        overlayColor: WidgetStatePropertyAll(
          palette.scorch.withValues(alpha: 0.22),
        ),
        customBorder: InkPlateBorder(
          borderRadius: Radii.key,
          side: BorderSide(color: edge, width: 1.25),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            label.toUpperCase(),
            style: Type.button.copyWith(
              color: ink,
              fontSize: 11,
              letterSpacing: 0.7,
            ),
          ),
        ),
      ),
    );
  }
}

class LedgerPlateRow<T> extends StatelessWidget {
  const LedgerPlateRow({
    super.key,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
  });

  final List<T> values;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: values.length,
        separatorBuilder: (_, __) => const SizedBox(width: Space.sm),
        itemBuilder: (context, i) {
          final value = values[i];
          return LedgerPlate(
            label: labelOf(value),
            selected: value == selected,
            onTap: () => onSelected(value),
          );
        },
      ),
    );
  }
}
