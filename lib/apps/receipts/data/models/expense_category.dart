/// What kind of thing an expense was.
///
/// Seeded with a sensible starting set and editable — a fixed enum would mean
/// a migration every time someone wants to track one more kind of spending.
class ExpenseCategory {
  const ExpenseCategory({this.id, required this.name, this.sort = 0});

  final int? id;
  final String name;
  final int sort;

  factory ExpenseCategory.fromMap(Map<String, Object?> m) => ExpenseCategory(
        id: m['id'] as int?,
        name: m['name']! as String,
        sort: m['sort']! as int,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'sort': sort,
      };

  @override
  bool operator ==(Object other) => other is ExpenseCategory && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
