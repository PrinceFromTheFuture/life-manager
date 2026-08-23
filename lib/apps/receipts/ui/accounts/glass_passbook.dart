import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:shopping_list/apps/receipts/data/expense_repository.dart';
import 'package:shopping_list/apps/receipts/data/models/account_mark.dart';
import 'package:shopping_list/apps/receipts/ui/accounts/move_chip.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/design/widgets/count_up_money.dart';
import 'package:shopping_list/core/util/money.dart';

/// A passbook page seen through frosted thermal paper.
///
/// The account's ink sits *behind* the frost so the page is identified by a
/// bloom, not by a painted rectangle. The well in the corner is the same
/// stamp language as a launcher tile.
class GlassPassbook extends StatelessWidget {
  const GlassPassbook({
    super.key,
    required this.standing,
    required this.inMinor,
    required this.outMinor,
    this.onOpen,
    this.onEdit,
  });

  final AccountStanding standing;
  final int inMinor;
  final int outMinor;
  final VoidCallback? onOpen;
  final VoidCallback? onEdit;

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
                    palette.paper.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: palette.paper.withValues(alpha: 0.42),
                  borderRadius: Radii.key,
                  border: Border.all(
                    color: Color.lerp(ink, palette.print, 0.25)!
                        .withValues(alpha: retired ? 0.22 : 0.48),
                    width: 1.25,
                  ),
                ),
                child: Material(
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
                                )
                              else if (onEdit != null)
                                IconButton(
                                  tooltip: 'Edit account',
                                  icon: const Icon(Icons.tune, size: 18),
                                  color: palette.faded,
                                  onPressed: onEdit,
                                ),
                            ],
                          ),
                          const Spacer(),
                          CountUpMoney(
                            key: ValueKey('bal-${account.id}'),
                            amountMinor: standing.balanceMinor,
                            style: Type.totalDisplay.copyWith(
                              color: retired ? palette.faded : palette.print,
                              fontSize: 34,
                              letterSpacing: -1.2,
                            ),
                          ),
                          const SizedBox(height: Space.sm),
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
    final palette = context.thermal;
    final ink = retired
        ? palette.faded
        : mark.ink.of(Theme.of(context).brightness);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: ink,
        borderRadius: Radii.key,
      ),
      child: Padding(
        padding: const EdgeInsets.all(Space.sm),
        child: Icon(mark.icon, size: 18, color: palette.paper),
      ),
    );
  }
}
