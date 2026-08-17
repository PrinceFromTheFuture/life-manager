import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/maps/android_api_headers.dart';
import 'package:shopping_list/core/settings/api_keys.dart';

/// The place an expense happened, printed as a Google Map on the slip.
///
/// The image is Maps Static API — same Google Cloud key already stored for
/// Vision, no second secret, no Maps SDK in the APK. Tapping it opens the
/// Google Maps app, which is the native next step.
class PlaceMap extends ConsumerWidget {
  const PlaceMap({
    super.key,
    required this.latitude,
    required this.longitude,
    this.label,
  });

  final double latitude;
  final double longitude;
  final String? label;

  Future<void> _openMaps() async {
    final name = label;
    final geo = Uri.parse(
      name == null || name.isEmpty
          ? 'geo:$latitude,$longitude?q=$latitude,$longitude'
          : 'geo:$latitude,$longitude?q=$latitude,$longitude(${Uri.encodeComponent(name)})',
    );
    if (await canLaunchUrl(geo)) {
      await launchUrl(geo, mode: LaunchMode.externalApplication);
      return;
    }
    await launchUrl(
      Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
      ),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.thermal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('PLACE', style: Type.eyebrow.copyWith(color: palette.faded)),
        const SizedBox(height: Space.sm),
        if ((label ?? '').isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.sm),
            child:
                Text(label!, style: Type.item.copyWith(color: palette.print)),
          ),
        Material(
          color: palette.paperShade,
          child: InkWell(
            onTap: _openMaps,
            child: SizedBox(
              height: 180,
              width: double.infinity,
              child: _StaticMap(
                latitude: latitude,
                longitude: longitude,
                onOpen: _openMaps,
              ),
            ),
          ),
        ),
        const SizedBox(height: Space.xs),
        Text(
          'Opens in Google Maps',
          style: Type.caption.copyWith(color: palette.faded),
        ),
      ],
    );
  }
}

class _StaticMap extends ConsumerWidget {
  const _StaticMap({
    required this.latitude,
    required this.longitude,
    required this.onOpen,
  });

  final double latitude;
  final double longitude;
  final VoidCallback onOpen;

  Future<ImageProvider?> _load(WidgetRef ref) async {
    final key =
        await ref.read(apiKeyStoreProvider).read(ApiKeyKind.googleVision);
    if (key == null || key.isEmpty) return null;

    final url = Uri.https('maps.googleapis.com', '/maps/api/staticmap', {
      'center': '$latitude,$longitude',
      'zoom': '16',
      'size': '640x320',
      'scale': '2',
      'maptype': 'roadmap',
      'markers': 'color:0x27506E|$latitude,$longitude',
      'key': key,
    });

    final response = await http.get(
      url,
      headers: await AndroidApiHeaders.get(),
    );
    if (response.statusCode != 200) return null;
    // Google returns a tiny error GIF/PNG with a 200 when the key is wrong;
    // a real map is tens of kilobytes.
    if (response.bodyBytes.length < 2048) return null;
    return MemoryImage(response.bodyBytes);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.thermal;

    return FutureBuilder<ImageProvider?>(
      future: _load(ref),
      builder: (context, snapshot) {
        final image = snapshot.data;
        if (snapshot.connectionState != ConnectionState.done) {
          return ColoredBox(
            color: palette.paperShade,
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: palette.faded,
                ),
              ),
            ),
          );
        }
        if (image == null) return _OpenInMaps(onOpen: onOpen);
        return Image(image: image, fit: BoxFit.cover);
      },
    );
  }
}

class _OpenInMaps extends StatelessWidget {
  const _OpenInMaps({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;

    return ColoredBox(
      color: palette.paperShade,
      child: Center(
        child: TextButton(
          onPressed: onOpen,
          child: const Text('Open in Google Maps'),
        ),
      ),
    );
  }
}
