import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/design/widgets/perforation.dart';
import 'package:shopping_list/core/util/money.dart';

/// The receipts app's signature moment.
///
/// Groceries has the thermal burn; this is its sibling rather than a repeat of
/// it. On save the expense **prints**: lines feed downward in mono, the total
/// lands last, a tear edge appears, and the slip tears off toward the spindle.
/// The register metaphor completed — you paid, it printed, the slip goes on the
/// spike.
///
/// It is short, tappable to skip, and skipped entirely under reduced motion.
/// Delight that you cannot get past is not delight.
Future<void> showPrintSlip(
  BuildContext context, {
  required String merchant,
  required int amountMinor,
  String? categoryName,
  required DateTime occurredAt,
}) {
  if (MediaQuery.disableAnimationsOf(context)) return Future<void>.value();

  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.transparent,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, __, ___) => _PrintSlip(
        merchant: merchant,
        amountMinor: amountMinor,
        categoryName: categoryName,
        occurredAt: occurredAt,
      ),
    ),
  );
}

class _PrintSlip extends StatefulWidget {
  const _PrintSlip({
    required this.merchant,
    required this.amountMinor,
    required this.categoryName,
    required this.occurredAt,
  });

  final String merchant;
  final int amountMinor;
  final String? categoryName;
  final DateTime occurredAt;

  @override
  State<_PrintSlip> createState() => _PrintSlipState();
}

class _PrintSlipState extends State<_PrintSlip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  Timer? _exit;

  @override
  void initState() {
    super.initState();
    _controller.forward();
    // Long enough to read the total, short enough not to be in the way.
    _exit = Timer(const Duration(milliseconds: 1150), _close);
  }

  @override
  void dispose() {
    _exit?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _close() {
    _exit?.cancel();
    if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;

    final lines = <Widget>[
      _Line(
        text: widget.merchant.toUpperCase(),
        style: Type.eyebrow.copyWith(color: palette.faded, fontSize: 12),
      ),
      if (widget.categoryName != null)
        _Line(
          text: widget.categoryName!.toUpperCase(),
          style: Type.eyebrow.copyWith(color: palette.faded, fontSize: 12),
        ),
      _Line(
        text: DateFormat('d MMM yyyy  HH:mm').format(widget.occurredAt),
        style: Type.mono.copyWith(color: palette.faded),
      ),
    ];

    return GestureDetector(
      onTap: _close,
      child: Material(
        color: palette.paper,
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.xl),
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final t = _controller.value;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _feed(t, 0.00, const PerforatedRule()),
                      const SizedBox(height: Space.lg),
                      for (var i = 0; i < lines.length; i++) ...[
                        // Each line arrives on its own beat, the way a print
                        // head advances the paper one row at a time.
                        _feed(t, 0.12 + i * 0.13, lines[i]),
                        const SizedBox(height: Space.sm),
                      ],
                      const SizedBox(height: Space.md),
                      _feed(t, 0.58, const PerforatedRule()),
                      const SizedBox(height: Space.lg),
                      _feed(
                        t,
                        0.66,
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              'TOTAL',
                              style:
                                  Type.eyebrow.copyWith(color: palette.faded),
                            ),
                            Text(
                              Money.format(widget.amountMinor),
                              style: Type.totalDisplay
                                  .copyWith(color: palette.print),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: Space.xl),
                      // The tear comes last: the slip is finished and comes off
                      // the roll.
                      _feed(t, 0.86, const TearEdge()),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Reveals [child] once the animation passes [start], sliding it down a few
  /// pixels as it appears so the column reads as paper advancing rather than
  /// text fading in.
  Widget _feed(double t, double start, Widget child) {
    const window = 0.16;
    final progress = ((t - start) / window).clamp(0.0, 1.0);
    final eased = Curves.easeOutCubic.transform(progress);

    return Opacity(
      opacity: eased,
      child: Transform.translate(
        offset: Offset(0, (1 - eased) * -10),
        child: child,
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.text, required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => Text(text, style: style);
}
