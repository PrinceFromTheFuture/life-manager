import 'package:flutter/material.dart';

import 'package:shopping_list/apps/receipts/data/models/category_ink.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';

/// The category's ink, as a printed mark — the same stamp language as the
/// hub feed's left bar, sized for a chip, a row, or the lookups list.
class CategoryStamp extends StatelessWidget {
  const CategoryStamp({
    super.key,
    required this.ink,
    this.size = 10,
  });

  final CategoryInk ink;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fill = ink.of(Theme.of(context).brightness);
    return Semantics(
      label: '${ink.label} ink',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: fill,
          borderRadius: Radii.media,
        ),
        child: SizedBox(width: size, height: size),
      ),
    );
  }
}

/// One pad from the closed pool. The name is the definition; the swatch is
/// how it prints.
class CategoryInkPad extends StatelessWidget {
  const CategoryInkPad({
    super.key,
    required this.ink,
    required this.selected,
    required this.onTap,
    this.showLabel = true,
  });

  final CategoryInk ink;
  final bool selected;
  final VoidCallback onTap;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    final fill = ink.of(Theme.of(context).brightness);

    final well = Material(
      color: fill,
      shape: RoundedRectangleBorder(
        borderRadius: Radii.key,
        side: BorderSide(
          color: selected ? palette.print : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: Radii.key,
        child: SizedBox(
          width: 44,
          height: 44,
          child: selected
              ? Icon(Icons.check, size: 18, color: palette.paper)
              : null,
        ),
      ),
    );

    if (!showLabel) {
      return Semantics(
        button: true,
        selected: selected,
        label: ink.label,
        child: well,
      );
    }

    return Semantics(
      button: true,
      selected: selected,
      label: ink.label,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          well,
          const SizedBox(height: 4),
          Text(
            ink.label,
            style: Type.caption.copyWith(
              color: selected ? palette.print : palette.faded,
            ),
          ),
        ],
      ),
    );
  }
}

/// Picks one of the predetermined stamp pads. Null if cancelled.
Future<CategoryInk?> showCategoryInkPicker({
  required BuildContext context,
  CategoryInk? selected,
  String title = 'Ink',
}) {
  final palette = context.thermal;
  return showDialog<CategoryInk>(
    context: context,
    useRootNavigator: false,
    builder: (context) => AlertDialog(
      backgroundColor: palette.paper,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      titleTextStyle: Type.display.copyWith(fontSize: 20, color: palette.print),
      title: Text(title),
      content: Wrap(
        spacing: Space.md,
        runSpacing: Space.md,
        children: [
          for (final ink in CategoryInk.all)
            CategoryInkPad(
              ink: ink,
              selected: ink.id == selected?.id,
              onTap: () => Navigator.of(context).pop(ink),
            ),
        ],
      ),
    ),
  );
}
