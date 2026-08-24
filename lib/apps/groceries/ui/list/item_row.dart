import 'package:flutter/material.dart';

import 'package:shopping_list/apps/groceries/data/models/trip_item.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/design/widgets/burn.dart';
import 'package:shopping_list/core/design/widgets/app_icon.dart';

/// One line on the list.
///
/// The two gestures are deliberately separated: the box on the left toggles
/// whether the item is in the cart, and the rest of the row opens its quantity.
/// Collapsing both into "tap anywhere" would make an accidental tap change the
/// wrong thing, and the recovery costs differ — a stray check is invisible
/// until checkout, while a stray quantity edit is obvious immediately.
class ItemRow extends StatelessWidget {
  const ItemRow({
    super.key,
    required this.item,
    required this.onToggle,
    this.onEdit,
    this.large = false,
  });

  final TripItem item;
  final VoidCallback onToggle;
  final VoidCallback? onEdit;

  /// Pick-Up Mode sizing: taller rows, bigger type, tap anywhere to check.
  final bool large;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;

    return ThermalSurface(
      burned: item.isPicked,
      builder: (context, background, ink) {
        final nameStyle = (large ? Type.itemLarge : Type.item).copyWith(
          color: ink,
        );
        final measureStyle = Type.mono.copyWith(
          color: item.isPicked ? ink : palette.faded,
          fontSize: large ? 16 : 14,
        );

        // In Pick-Up Mode the whole row is the target — precision tapping while
        // pushing a trolley is not a reasonable thing to ask for.
        if (large) {
          return Semantics(
            button: true,
            checked: item.isPicked,
            label: '${item.nameSnapshot}, ${item.measureLabel}',
            child: InkWell(
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Space.lg,
                  vertical: Space.lg + 6,
                ),
                child: Row(
                  children: [
                    _PrintBox(
                      checked: item.isPicked,
                      ink: ink,
                      background: background,
                      large: true,
                    ),
                    const SizedBox(width: Space.lg),
                    Expanded(
                      child: Text(item.nameSnapshot, style: nameStyle),
                    ),
                    const SizedBox(width: Space.md),
                    Text(item.measureLabel, style: measureStyle),
                  ],
                ),
              ),
            ),
          );
        }

        return Row(
          children: [
            Semantics(
              button: true,
              checked: item.isPicked,
              label: item.isPicked
                  ? 'Remove ${item.nameSnapshot} from cart'
                  : 'Put ${item.nameSnapshot} in cart',
              child: InkWell(
                onTap: onToggle,
                customBorder: const CircleBorder(),
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: Space.lg,
                    top: Space.md + 2,
                    bottom: Space.md + 2,
                    right: Space.sm,
                  ),
                  child: _PrintBox(
                    checked: item.isPicked,
                    ink: ink,
                    background: background,
                  ),
                ),
              ),
            ),
            Expanded(
              child: InkWell(
                onTap: onEdit,
                child: Padding(
                  padding: const EdgeInsets.only(
                    right: Space.lg,
                    top: Space.md + 2,
                    bottom: Space.md + 2,
                    left: Space.xs,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(item.nameSnapshot, style: nameStyle),
                      ),
                      const SizedBox(width: Space.md),
                      Text(item.measureLabel, style: measureStyle),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// A square, because forms and receipts use boxes. A circle here would read as
/// a radio button, which implies choosing one of several — the wrong promise.
class _PrintBox extends StatelessWidget {
  const _PrintBox({
    required this.checked,
    required this.ink,
    required this.background,
    this.large = false,
  });

  final bool checked;
  final Color ink;

  /// The row's colour behind this box. The tick is knocked out in this, which
  /// is what keeps it visible while the row is mid-burn and the background is
  /// somewhere between paper and print.
  final Color background;

  final bool large;

  @override
  Widget build(BuildContext context) {
    final size = large ? 26.0 : 20.0;

    return AnimatedContainer(
      duration: Motion.quick,
      width: size,
      height: size,
      decoration: BoxDecoration(
        border: Border.all(color: ink, width: 1.6),
        color: checked ? ink : Colors.transparent,
      ),
      child: checked
          ? AppIcon(SolarIcons.CheckCircle, size: size - 8, color: background)
          : null,
    );
  }
}
