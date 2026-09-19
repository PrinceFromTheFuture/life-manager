import 'package:shopping_list/apps/receipts/data/models/category_ink.dart';

/// What kind of thing an expense was.
///
/// Seeded with a sensible starting set and editable — a fixed enum would mean
/// a migration every time someone wants to track one more kind of spending.
/// Colour is one of [CategoryInk], so statistics can tell kinds apart without
/// inventing a new palette per screen.
class ExpenseCategory {
  const ExpenseCategory({
    this.id,
    required this.name,
    this.sort = 0,
    this.ink = CategoryInk.fallbackId,
  });

  final int? id;
  final String name;
  final int sort;

  /// Id of a [CategoryInk]. Resolved at the call site so this model stays a
  /// row, not a widget.
  final String ink;

  CategoryInk get stamp => CategoryInk.byId(ink);

  factory ExpenseCategory.fromMap(Map<String, Object?> m) => ExpenseCategory(
        id: m['id'] as int?,
        name: m['name']! as String,
        sort: m['sort']! as int,
        ink: m['ink'] as String? ?? CategoryInk.fallbackId,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'sort': sort,
        'ink': ink,
      };

  @override
  bool operator ==(Object other) => other is ExpenseCategory && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
