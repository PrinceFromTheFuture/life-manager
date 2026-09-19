/// When money actually leaves the account behind a payment method.
enum Settlement {
  /// The moment you pay. Cash, a bank transfer, a debit card.
  direct,

  /// On the statement day. Everything charged in between collects into one
  /// withdrawal.
  indirect,
}

/// A way of reaching an account.
///
/// Separate from [Account] because one account is usually reachable three ways
/// — transfer, debit card, credit card — and the third has completely different
/// timing from the other two. The expense records the *method*; which account
/// that drains is a property of the method, not of the purchase.
class PaymentMethod {
  const PaymentMethod({
    this.id,
    required this.accountId,
    required this.name,
    this.settlement = Settlement.direct,
    this.statementDay,
    this.creditLimitMinor,
    this.last4,
    this.sort = 0,
    this.archivedAt,
    required this.createdAt,
  });

  final int? id;
  final int accountId;
  final String name;
  final Settlement settlement;

  /// Day of the month the cycle closes, 1–31. Only meaningful when
  /// [isCredit]; days past 28 clamp to the last day of short months.
  final int? statementDay;

  /// Optional even on a credit card — plenty of cards have no limit worth
  /// tracking, and inventing one would make the cycle band lie.
  final int? creditLimitMinor;

  final String? last4;
  final int sort;

  /// Archived rather than deleted: a closed card still owns the history of
  /// everything charged to it.
  final DateTime? archivedAt;

  final DateTime createdAt;

  bool get isCredit => settlement == Settlement.indirect;
  bool get isArchived => archivedAt != null;

  /// What the chip shows: `Visa gold ·4471` reads better than either half.
  String get label => last4 == null || last4!.isEmpty ? name : '$name ·$last4';

  factory PaymentMethod.fromMap(Map<String, Object?> m) => PaymentMethod(
        id: m['id'] as int?,
        accountId: m['account_id']! as int,
        name: m['name']! as String,
        settlement: (m['settlement'] as String?) == 'indirect'
            ? Settlement.indirect
            : Settlement.direct,
        statementDay: m['statement_day'] as int?,
        creditLimitMinor: m['credit_limit_minor'] as int?,
        last4: m['last4'] as String?,
        sort: (m['sort'] as int?) ?? 0,
        archivedAt: m['archived_at'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(m['archived_at']! as int),
        createdAt:
            DateTime.fromMillisecondsSinceEpoch((m['created_at'] as int?) ?? 0),
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'account_id': accountId,
        'name': name,
        'settlement': settlement.name,
        'statement_day': statementDay,
        'credit_limit_minor': creditLimitMinor,
        'last4': last4,
        'sort': sort,
        'archived_at': archivedAt?.millisecondsSinceEpoch,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  PaymentMethod copyWith({
    int? id,
    int? accountId,
    String? name,
    Settlement? settlement,
    int? statementDay,
    int? creditLimitMinor,
    String? last4,
    int? sort,
    DateTime? archivedAt,
    bool clearStatementDay = false,
    bool clearCreditLimit = false,
  }) =>
      PaymentMethod(
        id: id ?? this.id,
        accountId: accountId ?? this.accountId,
        name: name ?? this.name,
        settlement: settlement ?? this.settlement,
        statementDay:
            clearStatementDay ? null : (statementDay ?? this.statementDay),
        creditLimitMinor: clearCreditLimit
            ? null
            : (creditLimitMinor ?? this.creditLimitMinor),
        last4: last4 ?? this.last4,
        sort: sort ?? this.sort,
        archivedAt: archivedAt ?? this.archivedAt,
        createdAt: createdAt,
      );

  @override
  bool operator ==(Object other) => other is PaymentMethod && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
