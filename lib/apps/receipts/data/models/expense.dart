import 'package:shopping_list/core/util/money.dart';

/// How an expense's fields were first filled in.
///
/// Kept on the record because a scanned expense that was never reviewed is a
/// different kind of data from one someone typed, and worth being able to tell
/// apart later.
enum ExpenseSource { manual, scanned }

/// One thing you paid for.
class Expense {
  const Expense({
    this.id,
    required this.occurredAt,
    required this.amountMinor,
    this.currency = Money.currencyCode,
    this.merchant,
    this.description,
    this.categoryId,
    this.accountId,
    this.locationLabel,
    this.latitude,
    this.longitude,
    required this.receiptPath,
    this.source = ExpenseSource.manual,
    this.ocrRaw,
    this.ocrModel,
    required this.createdAt,
    required this.updatedAt,
  });

  final int? id;
  final DateTime occurredAt;

  /// Agorot. Never a double — see [Money].
  final int amountMinor;

  final String currency;

  /// Where you paid. Null only if a scan produced nothing and you saved before
  /// filling it in.
  final String? merchant;

  final String? description;
  final int? categoryId;
  final int? accountId;

  /// A readable place, reverse-geocoded from [latitude]/[longitude] but freely
  /// editable — GPS puts you next door often enough that overriding has to be
  /// as easy as accepting.
  final String? locationLabel;

  final double? latitude;
  final double? longitude;

  /// Relative to the app documents directory, never absolute. Required.
  final String receiptPath;

  final ExpenseSource source;

  /// The raw OCR text, kept so a failed or wrong parse can be retried without
  /// photographing the receipt again.
  final String? ocrRaw;

  final String? ocrModel;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get amountLabel => Money.format(amountMinor);

  /// What the row shows as its heading. Falls back rather than rendering an
  /// empty line.
  String get title {
    if (merchant != null && merchant!.trim().isNotEmpty) return merchant!;
    if (description != null && description!.trim().isNotEmpty) {
      return description!;
    }
    return 'Expense';
  }

  factory Expense.fromMap(Map<String, Object?> m) => Expense(
        id: m['id'] as int?,
        occurredAt:
            DateTime.fromMillisecondsSinceEpoch(m['occurred_at']! as int),
        amountMinor: m['amount_minor']! as int,
        currency: (m['currency'] as String?) ?? Money.currencyCode,
        merchant: m['merchant'] as String?,
        description: m['description'] as String?,
        categoryId: m['category_id'] as int?,
        accountId: m['account_id'] as int?,
        locationLabel: m['location_label'] as String?,
        latitude: (m['latitude'] as num?)?.toDouble(),
        longitude: (m['longitude'] as num?)?.toDouble(),
        receiptPath: m['receipt_path']! as String,
        source: (m['source'] as String?) == 'scanned'
            ? ExpenseSource.scanned
            : ExpenseSource.manual,
        ocrRaw: m['ocr_raw'] as String?,
        ocrModel: m['ocr_model'] as String?,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(m['created_at']! as int),
        updatedAt:
            DateTime.fromMillisecondsSinceEpoch(m['updated_at']! as int),
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'occurred_at': occurredAt.millisecondsSinceEpoch,
        'amount_minor': amountMinor,
        'currency': currency,
        'merchant': merchant,
        'description': description,
        'category_id': categoryId,
        'account_id': accountId,
        'location_label': locationLabel,
        'latitude': latitude,
        'longitude': longitude,
        'receipt_path': receiptPath,
        'source': source.name,
        'ocr_raw': ocrRaw,
        'ocr_model': ocrModel,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
      };

  Expense copyWith({
    int? id,
    DateTime? occurredAt,
    int? amountMinor,
    String? merchant,
    String? description,
    int? categoryId,
    int? accountId,
    String? locationLabel,
    double? latitude,
    double? longitude,
    String? receiptPath,
    ExpenseSource? source,
    String? ocrRaw,
    String? ocrModel,
    DateTime? updatedAt,
  }) =>
      Expense(
        id: id ?? this.id,
        occurredAt: occurredAt ?? this.occurredAt,
        amountMinor: amountMinor ?? this.amountMinor,
        currency: currency,
        merchant: merchant ?? this.merchant,
        description: description ?? this.description,
        categoryId: categoryId ?? this.categoryId,
        accountId: accountId ?? this.accountId,
        locationLabel: locationLabel ?? this.locationLabel,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        receiptPath: receiptPath ?? this.receiptPath,
        source: source ?? this.source,
        ocrRaw: ocrRaw ?? this.ocrRaw,
        ocrModel: ocrModel ?? this.ocrModel,
        createdAt: createdAt,
        updatedAt: updatedAt ?? DateTime.now(),
      );

  @override
  bool operator ==(Object other) => other is Expense && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
