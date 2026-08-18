import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/design/widgets/perforation.dart';
import 'package:shopping_list/core/util/money.dart';

/// Where a credit card is, in the only two dimensions that matter.
///
/// Two hairlines of identical width, stacked, sharing one axis. The top one is
/// solid ink: money committed against the limit. The bottom one is perforated:
/// time elapsed through the statement cycle, with a single tick at today.
///
/// Because both start at the same left edge, the comparison needs no legend and
/// no second look — if the ink runs past the tick, you are spending faster than
/// the month is passing. That is the entire point of the widget, and it is why
/// this is two bars rather than one gauge with a percentage next to it.
class CycleBand extends StatelessWidget {
  const CycleBand({
    super.key,
    required this.committedMinor,
    required this.limitMinor,
    required this.cycleStart,
    required this.settlesOn,
    required this.now,
  });

  /// What has been charged in the open cycle and not yet settled.
  final int committedMinor;

  /// Null when no limit has been set — the money line is then omitted rather
  /// than drawn against an invented ceiling.
  final int? limitMinor;

  final DateTime cycleStart;
  final DateTime settlesOn;
  final DateTime now;

  static const double _barHeight = 8;

  double get _timeFraction {
    final span = settlesOn.difference(cycleStart).inSeconds;
    if (span <= 0) return 1;
    final elapsed = now.difference(cycleStart).inSeconds;
    return (elapsed / span).clamp(0.0, 1.0);
  }

  double? get _moneyFraction {
    final limit = limitMinor;
    if (limit == null || limit <= 0) return null;
    return (committedMinor / limit).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    final money = _moneyFraction;
    final time = _timeFraction;

    return Semantics(
      label: _spoken(),
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (money != null) ...[
              LayoutBuilder(
                builder: (context, constraints) => Stack(
                  children: [
                    Container(
                      height: _barHeight,
                      width: constraints.maxWidth,
                      color: palette.paperShade,
                    ),
                    AnimatedContainer(
                      duration: Motion.settle,
                      curve: Motion.heat,
                      height: _barHeight,
                      width: constraints.maxWidth * money,
                      color: palette.carbon,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Space.xs),
            ],
            LayoutBuilder(
              builder: (context, constraints) => SizedBox(
                height: 9,
                child: Stack(
                  children: [
                    const Positioned.fill(
                      child: Center(child: PerforatedRule()),
                    ),
                    Positioned(
                      left: (constraints.maxWidth - 1.5) * time,
                      top: 0,
                      bottom: 0,
                      child: Container(width: 1.5, color: palette.carbon),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: Space.sm),
            Text(
              caption(),
              style: Type.caption.copyWith(color: palette.faded),
            ),
          ],
        ),
      ),
    );
  }

  /// Both numbers in words, so the band is never the only way to read it.
  @visibleForTesting
  String caption() {
    final limit = limitMinor;
    final parts = <String>[
      if (limit == null || limit <= 0)
        Money.format(committedMinor)
      else
        '${Money.format(committedMinor)} of ${Money.format(limit)}',
      'settles ${DateFormat('d MMM').format(settlesOn)}',
    ];

    if (limit != null && limit > 0) {
      if (committedMinor > limit) {
        parts.add('over by ${Money.format(committedMinor - limit)}');
      } else {
        // What the month would have spent by now at an even burn. Only worth
        // saying when you are actually running hot.
        final expected = (limit * _timeFraction).round();
        if (committedMinor > expected) {
          parts.add(
            '${Money.format(committedMinor - expected)} ahead of the month',
          );
        }
      }
    }

    return parts.join(' · ');
  }

  String _spoken() => 'Cycle: ${caption()}';
}
