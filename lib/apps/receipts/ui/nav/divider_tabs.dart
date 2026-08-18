import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/design/widgets/perforation.dart';

/// The sections of the receipts app, drawn as the tabbed dividers of an
/// accordion receipt wallet.
///
/// There is no sliding indicator, no pill and no fill. A perforated rule runs
/// the full width underneath the labels and simply **stops** under the active
/// one: that gap is the whole affordance. The active divider reads as pulled
/// forward, and the paper below it belongs to that section.
///
/// The notch is measured from the label rather than snapped to the column, so
/// it hugs `SLIPS` and `ACCOUNTS` by different amounts — which is what makes it
/// look torn out by hand instead of computed.
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
    final palette = context.thermal;

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
            PerforatedRule(
              color: palette.perforation,
              notchStart: centre - notchWidth / 2,
              notchWidth: notchWidth,
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
