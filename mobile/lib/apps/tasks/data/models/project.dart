import 'package:shopping_list/apps/tasks/data/models/project_mark.dart';
import 'package:shopping_list/core/design/stamp_ink.dart';

/// A long-lived life priority. Completing one is rare; the spine lists the
/// living ones.
class Project {
  const Project({
    this.id,
    required this.name,
    required this.inkId,
    required this.iconId,
    this.sort = 0,
    this.archivedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final int? id;
  final String name;
  final String inkId;
  final String iconId;
  final int sort;
  final DateTime? archivedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isArchived => archivedAt != null;

  StampInk get ink => StampInk.byId(inkId);

  ProjectMark get mark => ProjectMark.byId(iconId);

  factory Project.fromMap(Map<String, Object?> m) => Project(
        id: m['id'] as int?,
        name: m['name']! as String,
        inkId: m['ink_id']! as String,
        iconId: m['icon_id']! as String,
        sort: m['sort']! as int,
        archivedAt: _millis(m['archived_at']),
        createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at']! as int),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(m['updated_at']! as int),
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'ink_id': inkId,
        'icon_id': iconId,
        'sort': sort,
        'archived_at': archivedAt?.millisecondsSinceEpoch,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
      };

  Project copyWith({
    int? id,
    String? name,
    String? inkId,
    String? iconId,
    int? sort,
    DateTime? archivedAt,
    bool clearArchived = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      Project(
        id: id ?? this.id,
        name: name ?? this.name,
        inkId: inkId ?? this.inkId,
        iconId: iconId ?? this.iconId,
        sort: sort ?? this.sort,
        archivedAt: clearArchived ? null : archivedAt ?? this.archivedAt,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

DateTime? _millis(Object? value) {
  if (value is! int) return null;
  return DateTime.fromMillisecondsSinceEpoch(value);
}
