import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/util/money.dart';

/// One line of a bank passbook.
///
/// The running balance is the reason this is not an ordinary list row. In an
/// append-only ledger the interesting question is rarely "how much was this
/// one" but "what was left afterwards", so the balance gets its own right-hand
/// column and the amount that caused it sits directly above.
class PassbookRow extends StatelessWidget {
  const PassbookRow({
    super.key,
    required this.label,
    required this.occurredAt,
    required this.amountMinor,
    required this.balanceMinor,
    this.onTap,
  });

  final String label;
  final DateTime occurredAt;

  /// Signed. Negative leaves the account, positive arrives.
  final int amountMinor;

  /// The account balance immediately after this entry.
  final int balanceMinor;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.lg,
          vertical: Space.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: Type.item.copyWith(color: palette.print),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: Space.md),
                Text(
                  Money.formatSigned(amountMinor),
                  style: Type.monoBold.copyWith(color: palette.print),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Expanded(
                  child: Text(
                    DateFormat('d MMM yyyy').format(occurredAt).toUpperCase(),
                    style: Type.caption.copyWith(color: palette.faded),
                  ),
                ),
                const SizedBox(width: Space.md),
                Text(
                  Money.format(balanceMinor),
                  style: Type.mono.copyWith(color: palette.faded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
