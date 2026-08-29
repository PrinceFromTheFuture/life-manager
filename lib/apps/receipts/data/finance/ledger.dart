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

  /// The lines that represent money actually moving.
  ///
  /// A reversed line and its reversal are bookkeeping: together they say the
  /// movement did not happen the way it was first recorded. Counting either of
  /// them in a gross figure turns one corrected slip into spending plus a
  /// refund that never arrived, which is how a single edited ₪60 receipt could
  /// read as ₪110 out and ₪50 in.
  ///
  /// Balances do not need this — a pair sums to zero on its own. It is the
  /// in-and-out splits, where the signs are counted separately, that have to
  /// leave corrections out.
  static List<LedgerLine> movement(List<LedgerLine> lines) {
    final corrected = <int>{
      for (final line in lines)
        if (line.entry.reversesId != null) line.entry.reversesId!,
    };
    return [
      for (final line in lines)
        if (line.entry.kind != LedgerKind.reversal &&
            !corrected.contains(line.entry.id))
          line,
    ];
  }

  /// The entry that undoes [original], for when an expense is edited away or
  /// deleted. Same amount, opposite sign, pointing back at what it cancels.
  ///
  /// It carries the date of the line it cancels, not the date you made the
  /// correction. A reversal is not money moving today — it is the statement
  /// that the original day's movement was wrong. Stamping it with "now" put a
  /// phantom credit into today and left the original day counting the slip
  /// twice. [when] records when the correction was made, on [createdAt].
  static AccountEntry reversalOf(AccountEntry original, {DateTime? when}) {
    final now = when ?? DateTime.now();
    return AccountEntry(
      accountId: original.accountId,
      occurredAt: original.occurredAt,
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
