import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shopping_list/apps/groceries/data/models/trip_item.dart';
import 'package:shopping_list/core/design/paper_snack.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/design/widgets/ink_plate.dart';
import 'package:shopping_list/core/design/widgets/perforation.dart';
import 'package:shopping_list/apps/groceries/state/providers.dart';

/// Units offered for a line. `null` means a plain count, shown as `×`.
const List<(String label, String? unit)> _units = [
  ('×', null),
  ('kg', 'kg'),
  ('g', 'g'),
  ('L', 'L'),
  ('ml', 'ml'),
  ('pack', 'pack'),
];

Future<void> showQuantitySheet(
  BuildContext context,
  WidgetRef ref,
  TripItem item,
) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: context.thermal.paper,
    isScrollControlled: true,
    builder: (_) => _QuantitySheet(item: item),
  );
}

class _QuantitySheet extends ConsumerStatefulWidget {
  const _QuantitySheet({required this.item});

  final TripItem item;

  @override
  ConsumerState<_QuantitySheet> createState() => _QuantitySheetState();
}

class _QuantitySheetState extends ConsumerState<_QuantitySheet> {
  late double _quantity = widget.item.quantity;
  late String? _unit = widget.item.unit;

  /// Whole units for counts, halves for weights and volumes — the steps people
  /// actually shop in.
  double get _step => _unit == null ? 1 : 0.5;

  void _bump(double delta) {
    // `num.clamp` is declared as returning num, so the result is narrowed back
    // explicitly rather than relying on analyzer special-casing.
    setState(
        () => _quantity = (_quantity + delta).clamp(0.0, 999.0).toDouble());
    unawaited(HapticFeedback.selectionClick());
  }

  String get _quantityLabel {
    if (_quantity == _quantity.roundToDouble())
      return _quantity.round().toString();
    return _quantity
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  Future<void> _save() async {
    final navigator = Navigator.of(context);
    await ref
        .read(activeListProvider.notifier)
        .setQuantity(widget.item, _quantity, unit: _unit);
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;

    return SafeArea(
      child: Padding(
        padding:
            const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, Space.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.item.nameSnapshot,
              style: Type.display.copyWith(color: palette.print, fontSize: 26),
            ),
            const SizedBox(height: Space.md),
            const PerforatedRule(),
            const SizedBox(height: Space.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _StepButton(
                  icon: Icons.remove,
                  onPressed: _quantity > 0 ? () => _bump(-_step) : null,
                ),
                Text(
                  _quantityLabel,
                  style: Type.totalDisplay.copyWith(color: palette.print),
                ),
                _StepButton(icon: Icons.add, onPressed: () => _bump(_step)),
              ],
            ),
            const SizedBox(height: Space.lg),
            Wrap(
              spacing: Space.sm,
              runSpacing: Space.sm,
              children: [
                for (final (label, unit) in _units)
                  _UnitChip(
                    label: label,
                    selected: _unit == unit,
                    onTap: () => setState(() => _unit = unit),
                  ),
              ],
            ),
            const SizedBox(height: Space.lg),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final navigator = Navigator.of(context);
                      final controller = ref.read(activeListProvider.notifier);
                      final removed = await controller.deleteItem(widget.item);
                      navigator.pop();
                      showPaperSnack(
                        context,
                        message: 'Removed ${removed.nameSnapshot}',
                        actionLabel: 'Undo',
                        onAction: () => controller.restoreItem(removed),
                      );
                    },
                    child: const Text('Remove'),
                  ),
                ),
                const SizedBox(width: Space.md),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: _save,
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    final enabled = onPressed != null;

    return InkPlate(
      onPressed: onPressed,
      primary: false,
      size: const Size(64, 64),
      child: Icon(
        icon,
        size: 28,
        color: enabled ? palette.print : palette.faded,
      ),
    );
  }
}

class _UnitChip extends StatelessWidget {
  const _UnitChip({
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

    return Material(
      color: selected ? palette.carbon : palette.paperShade,
      shape: InkPlateBorder(
        borderRadius: Radii.key,
        side: BorderSide(
          color: selected ? Plate.edge(palette) : palette.print,
          width: 1.5,
        ),
        insetColor: selected
            ? Plate.inset(light ? palette.paper : palette.print)
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: Radii.key,
        onTap: onTap,
        overlayColor: WidgetStatePropertyAll(
          palette.scorch.withValues(alpha: 0.18),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.lg,
            vertical: Space.md,
          ),
          child: Text(
            label,
            style: Type.monoBold.copyWith(
              color: selected
                  ? (light ? palette.paper : palette.print)
                  : palette.print,
            ),
          ),
        ),
      ),
    );
  }
}
