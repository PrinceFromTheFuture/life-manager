import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:shopping_list/apps/home/ui/home_palette.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';

/// The sections of the receipts app. The active word is bone, with a short
/// bar under it. The rest of the row is a hairline.
class DividerTabs extends StatelessWidget {
  const DividerTabs({
    super.key,
    required this.labels,
    required this.index,
    required this.onSelected,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onSelected;

  static const double _rowHeight = 44;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final column = width / labels.length;
        final labelWidth = _measure(labels[index], context);
        // Room for the notch to breathe on either side of the word.
        final notchWidth = labelWidth + Space.md * 2;
        final centre = column * index + column / 2;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: _rowHeight,
              child: Row(
                children: [
                  for (var i = 0; i < labels.length; i++)
                    Expanded(
                      child: _Tab(
                        label: labels[i],
                        active: i == index,
                        onTap: () => onSelected(i),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(
              height: 2,
              width: width,
              child: Stack(
                children: [
                  const Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: ColoredBox(
                      color: HomePalette.line,
                      child: SizedBox(height: 1),
                    ),
                  ),
                  Positioned(
                    left: centre - notchWidth / 2,
                    width: notchWidth,
                    bottom: 0,
                    height: 2,
                    child: const ColoredBox(color: HomePalette.bone),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// Width of a label at the eyebrow size, so the notch can be cut to fit it.
  static double _measure(String label, BuildContext context) {
    final painter = TextPainter(
      text: TextSpan(text: label.toUpperCase(), style: Type.eyebrow),
      textDirection: Directionality.of(context),
      maxLines: 1,
    )..layout();
    return painter.width;
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;

    return Semantics(
      button: true,
      selected: active,
      label: label,
      child: InkWell(
        onTap: () {
          unawaited(HapticFeedback.selectionClick());
          onTap();
        },
        child: Center(
          child: Text(
            label.toUpperCase(),
            style: Type.eyebrow.copyWith(
              color: active ? palette.print : palette.faded,
            ),
          ),
        ),
      ),
    );
  }
}
