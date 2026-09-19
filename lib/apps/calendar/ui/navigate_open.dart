import 'package:url_launcher/url_launcher.dart';

import 'package:shopping_list/apps/calendar/data/models/place.dart';
import 'package:shopping_list/apps/calendar/data/navigate_links.dart';

/// Hands a place to a maps app. Prefers the system `geo:` chooser.
abstract final class NavigateOpen {
  static Future<void> to(Place place) async {
    final lat = place.latitude;
    final lng = place.longitude;
    final geo = NavigateLinks.geo(lat, lng, name: place.title);
    if (await canLaunchUrl(geo)) {
      await launchUrl(geo, mode: LaunchMode.externalApplication);
      return;
    }
    for (final uri in [
      NavigateLinks.googleMaps(lat, lng),
      NavigateLinks.waze(lat, lng),
      NavigateLinks.appleMaps(lat, lng),
      NavigateLinks.googleMapsHttps(lat, lng),
      NavigateLinks.wazeHttps(lat, lng),
    ]) {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }
    await launchUrl(
      NavigateLinks.googleMapsHttps(lat, lng),
      mode: LaunchMode.externalApplication,
    );
  }
}
