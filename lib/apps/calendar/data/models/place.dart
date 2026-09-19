import 'package:shopping_list/apps/calendar/data/models/place_mark.dart';
import 'package:shopping_list/core/design/stamp_ink.dart';

/// A place this life actually goes — home, work, the gym, parents.
///
/// Events never invent a coordinate. They point here.
class Place {
  const Place({
    this.id,
    required this.title,
    required this.iconId,
    required this.inkId,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
  });

  final int? id;
  final String title;
  final String iconId;
  final String inkId;
  final double latitude;
  final double longitude;
  final DateTime createdAt;

  StampInk get ink => StampInk.byId(inkId);

  PlaceMark get mark => PlaceMark.byId(iconId);

  factory Place.fromMap(Map<String, Object?> m) => Place(
        id: m['id'] as int?,
        title: m['title']! as String,
        iconId: m['icon_id']! as String,
        inkId: m['ink_id']! as String,
        latitude: (m['latitude']! as num).toDouble(),
        longitude: (m['longitude']! as num).toDouble(),
        createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at']! as int),
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'title': title,
        'icon_id': iconId,
        'ink_id': inkId,
        'latitude': latitude,
        'longitude': longitude,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  Place copyWith({
    int? id,
    String? title,
    String? iconId,
    String? inkId,
    double? latitude,
    double? longitude,
  }) =>
      Place(
        id: id ?? this.id,
        title: title ?? this.title,
        iconId: iconId ?? this.iconId,
        inkId: inkId ?? this.inkId,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        createdAt: createdAt,
      );
}
