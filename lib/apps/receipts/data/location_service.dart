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
  /// a usable record of where it happened.
  Future<String?> _describe(double latitude, double longitude) async {
    try {
      final marks = await placemarkFromCoordinates(latitude, longitude);
      if (marks.isEmpty) return null;
      final mark = marks.first;

      // Street and town, skipping empty parts rather than emitting ", ,".
      final parts = [
        if ((mark.thoroughfare ?? '').isNotEmpty)
          [mark.thoroughfare, mark.subThoroughfare]
              .where((p) => (p ?? '').isNotEmpty)
              .join(' '),
        if ((mark.locality ?? '').isNotEmpty) mark.locality!,
      ].where((p) => p.trim().isNotEmpty).toList();

      return parts.isEmpty ? null : parts.join(', ');
    } on Exception {
      return null;
    }
  }
}
