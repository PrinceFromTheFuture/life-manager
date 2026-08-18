import 'package:shopping_list/apps/receipts/data/models/account_entry.dart';

/// One ledger line with the balance it left behind.
class LedgerLine {
  const LedgerLine({required this.entry, required this.balanceAfter});

  final AccountEntry entry;
  final int balanceAfter;
}

/// Reading an append-only ledger.
///
/// The balance is never stored. It is always `opening + Σ entries`, which means
/// there is exactly one place a wrong number can come from — a wrong entry —
/// and that entry is on screen next to the balance it produced.
abstract final class Ledger {
  static int balance({
    required int openingMinor,
    required Iterable<AccountEntry> entries,
  }) =>
      entries.fold(openingMinor, (sum, entry) => sum + entry.amountMinor);

  /// Runs the balance forward through [entries], which must be oldest first.
  /// Returned newest first, because that is the order a passbook is read.
  static List<LedgerLine> lines({
    required int openingMinor,
    required List<AccountEntry> entries,
  }) {
    var running = openingMinor;
    final lines = <LedgerLine>[];

    for (final entry in entries) {
      running += entry.amountMinor;
      lines.add(LedgerLine(entry: entry, balanceAfter: running));
    }

    return lines.reversed.toList();
  }

  /// The entry that undoes [original], for when an expense is edited away or
  /// deleted. Same amount, opposite sign, pointing back at what it cancels.
  static AccountEntry reversalOf(AccountEntry original, {DateTime? when}) {
    final now = when ?? DateTime.now();
    return AccountEntry(
      accountId: original.accountId,
      occurredAt: now,
      amountMinor: -original.amountMinor,
      kind: LedgerKind.reversal,
      refTable: original.refTable,
      refId: original.refId,
      reversesId: original.id,
      note: original.note,
      createdAt: now,
    );
  }
}
