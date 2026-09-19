/// Money arriving.
///
/// Deliberately thinner than an expense: no receipt, no category, no location,
/// no business flag. A typical month has a hundred expenses and one salary, so
/// the record that happens once should not carry the machinery built for the
/// record that happens constantly.
class Income {
  const Income({
    this.id,
    required this.occurredAt,
    required this.amountMinor,
    required this.sourceName,
    this.accountId,
    this.note,
    this.recurringRuleId,
    required this.createdAt,
  });

  final int? id;
  final DateTime occurredAt;
  final int amountMinor;

  /// Who paid you. Free text, suggested from what you have typed before.
  final String sourceName;

  /// Where it landed.
  final int? accountId;

  final String? note;

  /// Set when a standing order wrote this rather than you.
  final int? recurringRuleId;

  final DateTime createdAt;

  bool get isAutoCreated => recurringRuleId != null;

  factory Income.fromMap(Map<String, Object?> m) => Income(
        id: m['id'] as int?,
        occurredAt:
            DateTime.fromMillisecondsSinceEpoch(m['occurred_at']! as int),
        amountMinor: m['amount_minor']! as int,
        sourceName: m['source_name']! as String,
        accountId: m['account_id'] as int?,
        note: m['note'] as String?,
        recurringRuleId: m['recurring_rule_id'] as int?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at']! as int),
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'occurred_at': occurredAt.millisecondsSinceEpoch,
        'amount_minor': amountMinor,
        'source_name': sourceName,
        'account_id': accountId,
        'note': note,
        'recurring_rule_id': recurringRuleId,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  Income copyWith({
    int? id,
    DateTime? occurredAt,
    int? amountMinor,
    String? sourceName,
    int? accountId,
    String? note,
  }) =>
      Income(
        id: id ?? this.id,
        occurredAt: occurredAt ?? this.occurredAt,
        amountMinor: amountMinor ?? this.amountMinor,
        sourceName: sourceName ?? this.sourceName,
        accountId: accountId ?? this.accountId,
        note: note ?? this.note,
        recurringRuleId: recurringRuleId,
        createdAt: createdAt,
      );

  @override
  bool operator ==(Object other) => other is Income && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
