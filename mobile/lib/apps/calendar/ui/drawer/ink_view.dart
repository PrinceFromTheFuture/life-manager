import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:shopping_list/apps/calendar/data/models/place_mark.dart';
import 'package:shopping_list/apps/calendar/ui/drawer/drawer_parts.dart';
import 'package:shopping_list/apps/calendar/ui/night.dart';
import 'package:shopping_list/core/design/stamp_ink.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/design/widgets/app_icon.dart';
import 'package:shopping_list/core/design/widgets/multi_view_drawer.dart';

/// Pads of ink, in the closed set the whole product shares.
class InkGrid extends StatelessWidget {
  const InkGrid({
    super.key,
    required this.selected,
    required this.onPick,
    this.allowNone = false,
    this.noneLabel = 'None',
  });

  final String? selected;
  final ValueChanged<String?> onPick;
  final bool allowNone;
  final String noneLabel;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Space.md,
      runSpacing: Space.md,
      children: [
        if (allowNone)
          _Pad(
            label: noneLabel,
            color: null,
            selected: selected == null,
            onTap: () => onPick(null),
          ),
        for (final ink in StampInk.all)
          _Pad(
            label: ink.label,
            color: ink.dark,
            selected: selected == ink.id,
            onTap: () => onPick(ink.id),
          ),
      ],
    );
  }
}

class _Pad extends StatelessWidget {
  const _Pad({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color? color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 42,
          height: 42,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? Night.bone : Colors.transparent,
              width: 2,
            ),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color ?? Night.well,
              border: color == null ? Border.all(color: Night.line) : null,
            ),
            child: color == null
                ? const Center(
                    child: AppIcon(SolarIcons.CloseCircle, size: 16, color: Night.mist),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

/// Glyphs a place or event can wear.
class MarkGrid extends StatelessWidget {
  const MarkGrid({
    super.key,
    required this.selected,
    required this.onPick,
    this.ink,
    this.allowNone = false,
  });

  final String? selected;
  final ValueChanged<String?> onPick;
  final Color? ink;
  final bool allowNone;

  @override
  Widget build(BuildContext context) {
    Widget well(String? id, SolarIconData icon, String label) {
      final on = selected == id;
      return Semantics(
        button: true,
        selected: on,
        label: label,
        child: GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onPick(id);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: on ? (ink ?? Night.bone) : Night.well,
              borderRadius: const BorderRadius.all(Radius.circular(14)),
            ),
            child: Center(
              child: AppIcon(icon, size: 22, color: on ? Night.ink : Night.bone),
            ),
          ),
        ),
      );
    }

    return Wrap(
      spacing: Space.sm,
      runSpacing: Space.sm,
      children: [
        if (allowNone) well(null, SolarIcons.CloseCircle, 'None'),
        for (final mark in PlaceMark.all) well(mark.id, mark.icon, mark.label),
      ],
    );
  }
}

/// The stamp a single event is printed with. Without one it borrows its
/// place's ink.
class InkView extends StatelessWidget {
  const InkView({
    super.key,
    required this.listenable,
    required this.ink,
    required this.mark,
    required this.onInk,
    required this.onMark,
  });

  final Listenable listenable;
  final String? Function() ink;
  final String? Function() mark;
  final ValueChanged<String?> onInk;
  final ValueChanged<String?> onMark;

  @override
  Widget build(BuildContext context) {
    final drawer = MultiViewDrawer.of(context);
    return ListenableBuilder(
      listenable: listenable,
      builder: (context, _) {
        final current = ink();
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const DrawerViewHeader(title: 'Stamp'),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: Space.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const DrawerLabel('Ink'),
                    InkGrid(
                      selected: current,
                      allowNone: true,
                      noneLabel: 'From place',
                      onPick: onInk,
                    ),
                    const DrawerLabel('Mark'),
                    MarkGrid(
                      selected: mark(),
                      ink: current == null ? null : StampInk.byId(current).dark,
                      allowNone: true,
                      onPick: onMark,
                    ),
                    const SizedBox(height: Space.sm),
                    Text(
                      current == null
                          ? 'Printed in its place\'s ink.'
                          : 'Printed in ${StampInk.byId(current).label}.',
                      style: Type.caption.copyWith(color: Night.mist),
                    ),
                  ],
                ),
              ),
            ),
            DrawerFooter(
              children: [DrawerPrimaryButton(label: 'Done', onTap: drawer.pop)],
            ),
          ],
        );
      },
    );
  }
}
