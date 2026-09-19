import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/maps/android_api_headers.dart';
import 'package:shopping_list/core/settings/api_keys.dart';

/// A Static Maps confirmation of a pin. Same key as Vision; no Maps SDK.
class PlacePreview extends ConsumerWidget {
  const PlacePreview({
    super.key,
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;

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
      'markers': 'color:0x2F5A5A|$latitude,$longitude',
      'key': key,
    });

    final response = await http.get(
      url,
      headers: await AndroidApiHeaders.get(),
    );
    if (response.statusCode != 200) return null;
    if (response.bodyBytes.length < 2048) return null;
    return MemoryImage(response.bodyBytes);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.thermal;

    return SizedBox(
      height: 160,
      width: double.infinity,
      child: FutureBuilder<ImageProvider?>(
        future: _load(ref),
        builder: (context, snapshot) {
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
          final image = snapshot.data;
          if (image == null) {
            return ColoredBox(
              color: palette.paperShade,
              child: Center(
                child: Text(
                  '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}',
                  style: Type.mono.copyWith(color: palette.faded),
                ),
              ),
            );
          }
          return Image(image: image, fit: BoxFit.cover);
        },
      ),
    );
  }
}
