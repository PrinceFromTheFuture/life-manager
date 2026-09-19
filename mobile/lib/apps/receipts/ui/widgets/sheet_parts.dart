import 'package:flutter/material.dart';

import 'package:shopping_list/apps/receipts/data/models/category_ink.dart';
import 'package:shopping_list/apps/receipts/ui/register_keypad.dart';
import 'package:shopping_list/apps/receipts/ui/widgets/category_stamp.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/design/widgets/perforation.dart';
import 'package:shopping_list/core/util/money.dart';
import 'package:shopping_list/core/design/widgets/app_icon.dart';

/// One labelled section of a sheet, closed by a perforated rule.
///
/// The expense sheet established this rhythm — eyebrow, content, tear — and
/// every other sheet in the app now borrows it, so recording income does not
/// feel like a different product from recording an expense.
class SheetBlock extends StatelessWidget {
  const SheetBlock({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Type.eyebrow.copyWith(color: palette.faded)),
        const SizedBox(height: Space.sm),
        child,
        const SizedBox(height: Space.md),
        const PerforatedRule(),
        const SizedBox(height: Space.lg),
      ],
    );
  }
}

/// The big amount at the top of a sheet, tapped to open the keypad.
class SheetAmountRow extends StatelessWidget {
  const SheetAmountRow({
    super.key,
    required this.entry,
    required this.active,
    required this.onTap,
    this.sign,
  });

  final AmountEntry entry;
  final bool active;
  final VoidCallback onTap;

  /// A leading `+` on income. A bank statement differentiates the two
  /// directions with exactly this and nothing else, so neither does this app.
  final String? sign;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '${sign ?? ''}${Money.symbol}',
              style: Type.totalDisplay.copyWith(color: palette.faded),
            ),
            const SizedBox(width: Space.sm),
            Text(
              entry.display,
              style: Type.totalDisplay.copyWith(
                color: entry.isEmpty ? palette.faded : palette.print,
              ),
            ),
            const Spacer(),
            AppIcon(
              active ? SolarIcons.Minimize : SolarIcons.Calculator,
              size: 20,
              color: active ? palette.carbon : palette.faded,
            ),
          ],
        ),
      ),
    );
  }
}

/// The bottom bar of a sheet: one primary plate, and a line saying why it is
/// disabled rather than leaving you to guess.
class SheetSaveBar extends StatelessWidget {
  const SheetSaveBar({
    super.key,
    required this.label,
    required this.enabled,
    required this.onSave,
    this.hint,
    this.saving = false,
  });

  final String label;
  final bool enabled;
  final VoidCallback onSave;
  final String? hint;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;

    return Container(
      color: palette.paper,
      padding: EdgeInsets.fromLTRB(
        Space.lg,
        Space.md,
        Space.lg,
        Space.md + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hint != null) ...[
            Text(hint!, style: Type.caption.copyWith(color: palette.faded)),
            const SizedBox(height: Space.sm),
          ],
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: enabled && !saving ? onSave : null,
              child: Text(saving ? 'Saving…' : label),
            ),
          ),
        ],
      ),
    );
  }
}

/// A borderless field, the way every sheet in this app writes text input.
class SheetField extends StatelessWidget {
  const SheetField({
    super.key,
    required this.controller,
    required this.hintText,
    this.focusNode,
    this.style,
    this.capitalization = TextCapitalization.words,
    this.keyboardType,
    this.maxLines = 1,
    this.maxLength,
    this.onTap,
  });

  final TextEditingController controller;
  final String hintText;
  final FocusNode? focusNode;
  final TextStyle? style;
  final TextCapitalization capitalization;
  final TextInputType? keyboardType;
  final int maxLines;
  final int? maxLength;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;

    return TextField(
      controller: controller,
      focusNode: focusNode,
      textCapitalization: capitalization,
      keyboardType: keyboardType,
      maxLines: maxLines,
      maxLength: maxLength,
      style: style ?? Type.item.copyWith(color: palette.print),
      cursorColor: palette.carbon,
      decoration: InputDecoration(
        hintText: hintText,
        filled: false,
        counterText: '',
        isDense: true,
        contentPadding: EdgeInsets.zero,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
      ),
      onTap: onTap,
    );
  }
}

/// A pill for choosing one of a short list. The chip vocabulary the expense
/// sheet uses for categories and payment methods.
class SheetChip extends StatelessWidget {
  const SheetChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.ink,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// When set, the chip prints in this category's ink instead of the app's
  /// carbon. Payment-method chips leave it null.
  final CategoryInk? ink;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    final fill = ink?.of(Theme.of(context).brightness) ?? palette.carbon;
    // Paper is the contrasting ground in both themes: dark inks on a light
    // sheet, pastel inks on a dim one.
    final onFill = palette.paper;

    return Material(
      color: selected ? fill : palette.paperShade,
      borderRadius: Radii.control,
      child: InkWell(
        borderRadius: Radii.control,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.md + 2,
            vertical: Space.sm + 2,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (ink != null && !selected) ...[
                CategoryStamp(ink: ink!, size: 8),
                const SizedBox(width: Space.sm),
              ],
              Text(
                label,
                style: Type.body.copyWith(
                  color: selected ? onFill : palette.print,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
