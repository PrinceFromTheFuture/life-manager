import 'package:flutter/material.dart';

import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';

/// The small code a statement prints beside a line.
///
/// Real statements mark the lines that are not ordinary one-off card purchases
/// — a standing order, an installment plan — with a two or three character code
/// in the numeric column. Doing the same here means the slips list can carry
/// two new facts without the title column gaining a single pixel.
///
/// Two codes exist and that is the whole vocabulary. A third would turn a
/// glanceable margin into a legend nobody has memorised.
class MarginCode extends StatelessWidget {
  /// Written by a standing order rather than photographed by you.
  const MarginCode.standingOrder({super.key}) : _count = null;

  /// Split across more than one payment.
  const MarginCode.installments(int count, {super.key}) : _count = count;

  final int? _count;

  String get _text => _count == null ? 'S/O' : 'x$_count';

  String get _spoken =>
      _count == null ? 'Standing order' : '$_count payments';

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;

    return Semantics(
      label: _spoken,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(right: Space.sm),
        child: Text(
          _text,
          style: Type.eyebrow.copyWith(color: palette.faded),
        ),
      ),
    );
  }
}
