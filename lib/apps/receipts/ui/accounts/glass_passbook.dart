import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:shopping_list/apps/receipts/data/expense_repository.dart';
import 'package:shopping_list/apps/receipts/data/models/account_mark.dart';
import 'package:shopping_list/apps/receipts/ui/accounts/move_chip.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/design/widgets/app_icon.dart';
import 'package:shopping_list/core/design/widgets/count_up_money.dart';
import 'package:shopping_list/core/util/money.dart';

/// A passbook page seen through frosted white glass.
///
/// The account's ink sits *behind* the frost so the page is identified by a
/// bloom, not by a painted rectangle. The fill is white at 20% so the bloom
/// still reads through. The edge is the same ink, fading through half-strength
/// to nothing. The well matches the launcher: ink glyph on a 10% wash.
class GlassPassbook extends StatelessWidget {
  const GlassPassbook({
    super.key,
    required this.standing,
    required this.inMinor,
    required this.outMinor,
    this.onOpen,
  });

  final AccountStanding standing;
  final int inMinor;
  final int outMinor;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    final account = standing.account;
    final mark = account.stamp;
    final brightness = Theme.of(context).brightness;
    final ink = mark.ink.of(brightness);
    final retired = account.isArchived;

    return Semantics(
      button: onOpen != null,
      label: '${account.name}, ${Money.format(standing.balanceMinor)}',
      child: ClipRRect(
        borderRadius: Radii.key,
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.7, -0.8),
                  radius: 1.15,
                  colors: [
                    ink.withValues(alpha: retired ? 0.18 : 0.42),
                    ink.withValues(alpha: retired ? 0.04 : 0.10),
                    ink.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.10),
                      borderRadius: Radii.key,
                    ),
                  ),
                  ShaderMask(
                    blendMode: BlendMode.srcIn,
                    shaderCallback: (bounds) => LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        ink.withValues(alpha: retired ? 0.40 : 1),
                        ink.withValues(alpha: retired ? 0.20 : 0.50),
                        ink.withValues(alpha: 0),
                      ],
                    ).createShader(bounds),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: Radii.key,
                        border: Border.all(color: Colors.white, width: 1.25),
                      ),
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onOpen,
                      overlayColor: WidgetStatePropertyAll(
                        ink.withValues(alpha: 0.12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          Space.lg,
                          Space.md,
                          Space.md,
                          Space.md,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                _MarkWell(mark: mark, retired: retired),
                                const SizedBox(width: Space.md),
                                Expanded(
                                  child: Text(
                                    account.name.toUpperCase(),
                                    style: Type.eyebrow.copyWith(
                                      color: retired
                                          ? palette.faded
                                          : palette.print,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (retired)
                                  Text(
                                    'RETIRED',
                                    style: Type.eyebrow
                                        .copyWith(color: palette.faded),
                                  ),
                              ],
                            ),
                            const Spacer(),
                            CountUpMoney(
                              key: ValueKey('bal-${account.id}'),
                              amountMinor: standing.balanceMinor,
                              style: Type.totalDisplay.copyWith(
                                color: retired ? palette.faded : palette.print,
                                fontSize: 32,
                                letterSpacing: -1.2,
                              ),
                            ),
                            const SizedBox(height: Space.xs),
                            Row(
                              children: [
                                MoveChip(amountMinor: inMinor, compact: true),
                                if (inMinor != 0 && outMinor != 0)
                                  const SizedBox(width: Space.md),
                                MoveChip(amountMinor: -outMinor, compact: true),
                                if (inMinor == 0 && outMinor == 0)
                                  Text(
                                    'No move today',
                                    style: Type.caption
                                        .copyWith(color: palette.faded),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarkWell extends StatelessWidget {
  const _MarkWell({required this.mark, required this.retired});

  final AccountMark mark;
  final bool retired;

  @override
  Widget build(BuildContext context) {
    final ink = retired
        ? context.thermal.faded
        : mark.ink.of(Theme.of(context).brightness);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: ink.withValues(alpha: 0.10),
        borderRadius: Radii.key,
      ),
      child: Padding(
        padding: const EdgeInsets.all(Space.sm),
        child: AppIcon(mark.icon, size: 18, color: ink),
      ),
    );
  }
}
