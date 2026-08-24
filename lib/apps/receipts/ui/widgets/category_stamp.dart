import 'package:flutter/material.dart';

import 'package:shopping_list/apps/receipts/data/models/category_ink.dart';
import 'package:shopping_list/core/design/widgets/ink_pad.dart';

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
  Widget build(BuildContext context) => StampMark(ink: ink, size: size);
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
  Widget build(BuildContext context) => StampInkPad(
        ink: ink,
        selected: selected,
        onTap: onTap,
        showLabel: showLabel,
      );
}

/// Picks one of the predetermined stamp pads. Null if cancelled.
Future<CategoryInk?> showCategoryInkPicker({
  required BuildContext context,
  CategoryInk? selected,
  String title = 'Ink',
}) =>
    showStampInkPicker(
      context: context,
      selected: selected,
      title: title,
    );
