/// What a rule writes when it runs.
enum RecurringKind { expense, income }

/// A standing order: something that happens on the same day every month
/// whether or not you remember it.
///
/// The shape is an expense with the situational fields removed — no photo, no
/// GPS, no scan provenance — plus the two facts an expense never has: which day
/// of the month it lands on, and how far the sweep has already got.
class RecurringRule {
  const RecurringRule({
    this.id,
    this.kind = RecurringKind.expense,
    required this.name,
    required this.amountMinor,
    this.categoryId,
    this.paymentMethodId,
    this.accountId,
    required this.dayOfMonth,
    this.isBusiness = false,
    this.note,
    required this.startsOn,
    this.endsOn,
    this.lastRunOn,
    this.active = true,
    required this.createdAt,
  });

  final int? id;
  final RecurringKind kind;
  final String name;
  final int amountMinor;

  /// Expense rules only.
  final int? categoryId;
  final int? paymentMethodId;

  /// Income rules only — which account the money lands in.
  final int? accountId;

  /// 1–31. Days past 28 run on the last day of short months.
  final int dayOfMonth;

  final bool isBusiness;
  final String? note;

  /// Local midnight on the day the rule starts. Nothing is written before it.
  final DateTime startsOn;

  final DateTime? endsOn;

  /// The high-water mark of the sweep. Everything about idempotency hangs off
  /// this: the materializer only looks forward from here, so running it twice
  /// in one day writes nothing the second time.
  final DateTime? lastRunOn;

  /// A paused rule keeps its history and stops writing. Deleting would lose
  /// the link from the slips it already posted.
  final bool active;

  final DateTime createdAt;

  bool get isIncome => kind == RecurringKind.income;

  factory RecurringRule.fromMap(Map<String, Object?> m) => RecurringRule(
        id: m['id'] as int?,
        kind: (m['kind'] as String?) == 'income'
            ? RecurringKind.income
            : RecurringKind.expense,
        name: m['name']! as String,
        amountMinor: m['amount_minor']! as int,
        categoryId: m['category_id'] as int?,
        paymentMethodId: m['payment_method_id'] as int?,
        accountId: m['account_id'] as int?,
        dayOfMonth: m['day_of_month']! as int,
        isBusiness: (m['is_business'] as int? ?? 0) == 1,
        note: m['note'] as String?,
        startsOn: DateTime.fromMillisecondsSinceEpoch(m['starts_on']! as int),
        endsOn: m['ends_on'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(m['ends_on']! as int),
        lastRunOn: m['last_run_on'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(m['last_run_on']! as int),
        active: (m['active'] as int? ?? 1) == 1,
        createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at']! as int),
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'kind': kind.name,
        'name': name,
        'amount_minor': amountMinor,
        'category_id': categoryId,
        'payment_method_id': paymentMethodId,
        'account_id': accountId,
        'day_of_month': dayOfMonth,
        'is_business': isBusiness ? 1 : 0,
        'note': note,
        'starts_on': startsOn.millisecondsSinceEpoch,
        'ends_on': endsOn?.millisecondsSinceEpoch,
        'last_run_on': lastRunOn?.millisecondsSinceEpoch,
        'active': active ? 1 : 0,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  RecurringRule copyWith({
    int? id,
    RecurringKind? kind,
    String? name,
    int? amountMinor,
    int? categoryId,
    int? paymentMethodId,
    int? accountId,
    int? dayOfMonth,
    bool? isBusiness,
    String? note,
    DateTime? startsOn,
    DateTime? endsOn,
    DateTime? lastRunOn,
    bool? active,
    bool clearEndsOn = false,
  }) =>
      RecurringRule(
        id: id ?? this.id,
        kind: kind ?? this.kind,
        name: name ?? this.name,
        amountMinor: amountMinor ?? this.amountMinor,
        categoryId: categoryId ?? this.categoryId,
        paymentMethodId: paymentMethodId ?? this.paymentMethodId,
        accountId: accountId ?? this.accountId,
        dayOfMonth: dayOfMonth ?? this.dayOfMonth,
        isBusiness: isBusiness ?? this.isBusiness,
        note: note ?? this.note,
        startsOn: startsOn ?? this.startsOn,
        endsOn: clearEndsOn ? null : (endsOn ?? this.endsOn),
        lastRunOn: lastRunOn ?? this.lastRunOn,
        active: active ?? this.active,
        createdAt: createdAt,
      );

  @override
  bool operator ==(Object other) => other is RecurringRule && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
