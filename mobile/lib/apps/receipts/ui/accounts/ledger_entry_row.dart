import 'package:flutter/material.dart';
import 'package:flutty_solar_icons/solar_icons_flutter.dart';
import 'package:intl/intl.dart';

import 'package:shopping_list/apps/home/ui/home_palette.dart';
import 'package:shopping_list/apps/receipts/data/finance/ledger.dart';
import 'package:shopping_list/apps/receipts/data/models/account_entry.dart';
import 'package:shopping_list/apps/receipts/data/models/category_ink.dart';
import 'package:shopping_list/apps/receipts/ui/accounts/ledger_ref.dart';
import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/util/money.dart';

/// One passbook line. The move is coloured; the running balance stays print.
class LedgerEntryRow extends StatelessWidget {
  const LedgerEntryRow({super.key, required this.line});

  final LedgerLine line;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;
    final entry = line.entry;
    final arriving = entry.amountMinor >= 0;
    final brightness = context.stampBrightness;
    final moveInk = arriving
        ? CategoryInk.pine.of(brightness)
        : CategoryInk.carmine.of(brightness);
    final opens = ledgerReferenceOpens(entry);
    final subtitle = _subtitle(entry);

    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.sm),
      child: Material(
        color: HomePalette.tile,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: opens ? () => openLedgerReference(context, entry) : null,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: moveInk.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: SolarIcon(
                      arriving
                          ? SolarIcons.ArrowLeftDown
                          : SolarIcons.ArrowRightUp,
                      weight: SolarIconWeight.linear,
                      size: 18,
                      color: moveInk,
                    ),
                  ),
                ),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _label(entry),
                        style: Type.item.copyWith(color: palette.print),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: Type.caption.copyWith(color: palette.faded),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: Space.md),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      Money.formatSigned(entry.amountMinor),
                      style: Type.monoBold.copyWith(color: moveInk),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      Money.format(line.balanceAfter),
                      style: Type.mono.copyWith(
                        color: palette.faded,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _label(AccountEntry entry) {
    final note = (entry.note ?? '').trim();
    return switch (entry.kind) {
      LedgerKind.reversal => note.isEmpty ? 'Reversal' : 'Reversal · $note',
      LedgerKind.opening => 'Opening balance',
      LedgerKind.adjustment => note.isEmpty ? 'Adjustment' : note,
      LedgerKind.income => note.isEmpty ? 'Income' : note,
      LedgerKind.expense => note.isEmpty ? 'Expense' : note,
      LedgerKind.settlement => note.isEmpty ? 'Statement' : note,
      LedgerKind.transfer => note.isEmpty ? 'Transfer' : note,
    };
  }

  static String? _subtitle(AccountEntry entry) {
    final date = DateFormat('d MMM').format(entry.occurredAt).toUpperCase();
    final kind = switch (entry.kind) {
      LedgerKind.income => 'In',
      LedgerKind.expense => 'Out',
      LedgerKind.settlement => 'Statement',
      LedgerKind.reversal => 'Reversal',
      LedgerKind.opening => 'Opening',
      LedgerKind.adjustment => 'Adjustment',
      LedgerKind.transfer => 'Transfer',
    };
    return '$kind · $date';
  }
}
