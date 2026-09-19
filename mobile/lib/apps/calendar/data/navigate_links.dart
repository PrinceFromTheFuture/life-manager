/// Deeplinks that hand a place to a maps app. Navigation itself is theirs.
abstract final class NavigateLinks {
  static Uri geo(double latitude, double longitude, {String? name}) {
    final q = name == null || name.isEmpty
        ? '$latitude,$longitude'
        : '$latitude,$longitude(${Uri.encodeComponent(name)})';
    return Uri.parse('geo:$latitude,$longitude?q=$q');
  }

  static Uri googleMaps(double latitude, double longitude) => Uri.parse(
        'comgooglemaps://?daddr=$latitude,$longitude&directionsmode=driving',
      );

  static Uri googleMapsHttps(double latitude, double longitude) => Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude',
      );

  static Uri waze(double latitude, double longitude) => Uri.parse(
        'waze://?ll=$latitude,$longitude&navigate=yes',
      );

  static Uri wazeHttps(double latitude, double longitude) => Uri.parse(
        'https://waze.com/ul?ll=$latitude,$longitude&navigate=yes',
      );

  static Uri appleMaps(double latitude, double longitude) => Uri.parse(
        'maps://?daddr=$latitude,$longitude',
      );
}
