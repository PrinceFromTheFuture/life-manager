import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

/// Where you were, as far as the phone can tell.
class PlaceGuess {
  const PlaceGuess({this.label, this.latitude, this.longitude});

  static const PlaceGuess unknown = PlaceGuess();

  final String? label;
  final double? latitude;
  final double? longitude;

  bool get hasAny => label != null || latitude != null;
}

/// Resolves the current location into something readable.
///
/// **This never throws and never blocks.** Location is a convenience on an
/// expense, not a requirement — permission refused, GPS off, no signal indoors,
/// or a geocoder that times out all resolve to [PlaceGuess.unknown] and the
/// form simply shows an empty, editable field. An expense must always be
/// savable standing in a basement car park.
class LocationService {
  const LocationService();

  Future<PlaceGuess> currentPlace({
    Duration timeout = const Duration(seconds: 6),
  }) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return PlaceGuess.unknown;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return PlaceGuess.unknown;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: timeout,
        ),
      );

      final label = await _describe(position.latitude, position.longitude);
      return PlaceGuess(
        label: label,
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } on Exception {
      return PlaceGuess.unknown;
    }
  }

  /// Turns coordinates into something a person recognises.
  ///
  /// Coordinates are still returned even when this fails, so the expense keeps
  /// a usable record of where it happened even without a readable name.
  Future<String?> _describe(double latitude, double longitude) async {
    try {
      // geocoding 5 moved from top-level functions to an instance API.
      final marks =
          await Geocoding().placemarkFromCoordinates(latitude, longitude);
      if (marks.isEmpty) return null;
      final mark = marks.first;

      // Street then town, skipping empty parts rather than emitting ", ,".
      final street = <String?>[mark.thoroughfare, mark.subThoroughfare]
          .whereType<String>()
          .where((part) => part.trim().isNotEmpty)
          .join(' ');
      final town = mark.locality ?? '';

      final parts = <String>[
        if (street.trim().isNotEmpty) street.trim(),
        if (town.trim().isNotEmpty) town.trim(),
      ];

      return parts.isEmpty ? null : parts.join(', ');
    } on Exception {
      return null;
    }
  }
}
