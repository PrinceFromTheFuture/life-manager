import 'package:flutter/material.dart';

import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/design/widgets/ink_plate.dart';

/// A quiet label on an account card — a payment method, a state, nothing
/// tappable. The card itself is the tap target.
class MetaChip extends StatelessWidget {
  const MetaChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;

    return Material(
      color: palette.paper,
      shape: InkPlateBorder(
        borderRadius: Radii.key,
        side: BorderSide(
          color: palette.print.withValues(alpha: 0.22),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: 5),
        child: Text(
          label,
          style: Type.caption.copyWith(color: palette.print, fontSize: 12),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
