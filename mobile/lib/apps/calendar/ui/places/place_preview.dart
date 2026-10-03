import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'package:shopping_list/core/design/theme.dart';
import 'package:shopping_list/core/design/tokens.dart';
import 'package:shopping_list/core/maps/android_api_headers.dart';
import 'package:shopping_list/core/settings/api_keys.dart';

/// A Static Maps confirmation of a pin. Same key as Vision; no Maps SDK.
///
/// The image is fetched once per pin; rebuilding the preview — inside an
/// animating drawer, say — reuses it.
class PlacePreview extends ConsumerStatefulWidget {
  const PlacePreview({
    super.key,
    required this.latitude,
    required this.longitude,
    this.height = 160,
  });

  final double latitude;
  final double longitude;
  final double height;

  @override
  ConsumerState<PlacePreview> createState() => _PlacePreviewState();
}

class _PlacePreviewState extends ConsumerState<PlacePreview> {
  late Future<ImageProvider?> _image = _load();

  @override
  void didUpdateWidget(PlacePreview old) {
    super.didUpdateWidget(old);
    if (old.latitude != widget.latitude || old.longitude != widget.longitude) {
      _image = _load();
    }
  }

  Future<ImageProvider?> _load() async {
    final latitude = widget.latitude;
    final longitude = widget.longitude;
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

    try {
      final response = await http.get(
        url,
        headers: await AndroidApiHeaders.get(),
      );
      if (response.statusCode != 200) return null;
      if (response.bodyBytes.length < 2048) return null;
      return MemoryImage(response.bodyBytes);
    } on Exception {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.thermal;

    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: FutureBuilder<ImageProvider?>(
        future: _image,
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
                  '${widget.latitude.toStringAsFixed(5)}, '
                  '${widget.longitude.toStringAsFixed(5)}',
                  style: Type.mono.copyWith(color: palette.faded),
                ),
              ),
            );
          }
          return Image(image: image, fit: BoxFit.cover, gaplessPlayback: true);
        },
      ),
    );
  }
}
