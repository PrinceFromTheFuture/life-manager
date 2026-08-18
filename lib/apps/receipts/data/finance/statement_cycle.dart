import 'package:shopping_list/apps/receipts/data/finance/calendar.dart';

/// One billing period of a credit payment method.
///
/// Half-open, `[start, end)`, so a charge made exactly on the statement day
/// belongs to the cycle that is opening rather than the one that just closed —
/// which is what the card issuer does, and what anyone reading their own
/// statement expects.
class StatementCycle {
  const StatementCycle({required this.start, required this.end});

  final DateTime start;

  /// Exclusive. Also the day the whole cycle leaves the account.
  final DateTime end;

  DateTime get settlesOn => end;

  bool contains(DateTime when) => !when.isBefore(start) && when.isBefore(end);

  bool hasClosedBy(DateTime now) => !now.isBefore(end);

  @override
  bool operator ==(Object other) =>
      other is StatementCycle && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'StatementCycle($start -> $end)';
}

abstract final class StatementCycles {
  /// A safety rail on the walk below. Twenty years of monthly cycles is far
  /// more than any real ledger, and an unbounded `while` over dates is exactly
  /// the kind of loop that hangs an app on one bad row.
  static const int _maxCycles = 240;

  /// The cycle containing [when] for a method that resets on [statementDay].
  static StatementCycle containing(DateTime when, int statementDay) {
    final day = Calendar.startOfDay(when);
    final anchor = Calendar.dayOf(when.year, when.month, statementDay);

    if (day.isBefore(anchor)) {
      return StatementCycle(
        start: Calendar.dayOf(when.year, when.month - 1, statementDay),
        end: anchor,
      );
    }
    return StatementCycle(
      start: anchor,
      end: Calendar.dayOf(when.year, when.month + 1, statementDay),
    );
  }

  /// The cycle currently collecting charges.
  static StatementCycle open(DateTime now, int statementDay) =>
      containing(now, statementDay);

  /// Every cycle that has finished on or before [now] and ended after [after].
  ///
  /// [after] is normally the last settlement already posted, so the sweep only
  /// ever considers periods it has not accounted for. Returned oldest first, so
  /// settlements post in the order they happened.
  static List<StatementCycle> closedSince({
    required DateTime after,
    required DateTime now,
    required int statementDay,
  }) {
    final cycles = <StatementCycle>[];
    var cycle = containing(after, statementDay);

    for (var i = 0; i < _maxCycles; i++) {
      if (!cycle.hasClosedBy(now)) break;
      if (cycle.end.isAfter(after)) cycles.add(cycle);
      cycle = containing(cycle.end, statementDay);
    }

    return cycles;
  }
}
