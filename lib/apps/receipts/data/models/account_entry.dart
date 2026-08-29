/// Why a line exists in the ledger.
enum LedgerKind {
  /// What the account held on the day you started tracking it.
  opening,

  /// A direct payment leaving the account.
  expense,

  /// Money arriving.
  income,

  /// A credit cycle closing — the whole statement leaving in one withdrawal.
  settlement,

  /// Undoes an earlier entry. Written when an expense is edited or deleted,
  /// because the original line is never touched.
  reversal,

  /// A manual correction that does not correspond to any other record.
  adjustment,
}

/// One immutable line of an account's history.
///
/// No amount here is ever rewritten and no line is ever deleted. A mistake is
/// corrected by appending a [LedgerKind.reversal] that points at the line it
/// undoes, which is why the account screen can show you not just the balance
/// but how it got there. The one field that does get rewritten in place is
/// [note], a cached label that no sum depends on.
class AccountEntry {
  const AccountEntry({
    this.id,
    required this.accountId,
    required this.occurredAt,
    required this.amountMinor,
    required this.kind,
    this.refTable,
    this.refId,
    this.reversesId,
    this.note,
    required this.createdAt,
  });

  final int? id;
  final int accountId;
  final DateTime occurredAt;

  /// Signed agorot. Negative leaves the account, positive arrives.
  final int amountMinor;

  final LedgerKind kind;

  /// What this line came from, so tapping it can open the slip.
  final String? refTable;
  final int? refId;

  /// Set only on a reversal.
  final int? reversesId;

  final String? note;
  final DateTime createdAt;

  factory AccountEntry.fromMap(Map<String, Object?> m) => AccountEntry(
        id: m['id'] as int?,
        accountId: m['account_id']! as int,
        occurredAt:
            DateTime.fromMillisecondsSinceEpoch(m['occurred_at']! as int),
        amountMinor: m['amount_minor']! as int,
        kind: LedgerKind.values.firstWhere(
          (k) => k.name == m['kind'],
          orElse: () => LedgerKind.adjustment,
        ),
        refTable: m['ref_table'] as String?,
        refId: m['ref_id'] as int?,
        reversesId: m['reverses_id'] as int?,
        note: m['note'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at']! as int),
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'account_id': accountId,
        'occurred_at': occurredAt.millisecondsSinceEpoch,
        'amount_minor': amountMinor,
        'kind': kind.name,
        'ref_table': refTable,
        'ref_id': refId,
        'reverses_id': reversesId,
        'note': note,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  @override
  bool operator ==(Object other) => other is AccountEntry && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
