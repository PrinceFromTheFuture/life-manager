import 'package:flutter/services.dart';

/// Headers Google requires when an API key is restricted to this Android app.
///
/// Unrestricted keys ignore them. Restricted ones reject the request without
/// `X-Android-Package` and `X-Android-Cert`, which is the usual reason Vision
/// "doesn't work" on a phone even though the same key works from a browser.
class AndroidApiHeaders {
  static const _channel = MethodChannel('spindle/android');
  static const String packageName = 'com.amirw.shopping_list';

  static Map<String, String>? _cached;

  static Future<Map<String, String>> get() async {
    if (_cached != null) return _cached!;
    try {
      final sha1 = await _channel.invokeMethod<String>('signingCertSha1');
      if (sha1 == null || sha1.isEmpty) return const {};
      _cached = {
        'X-Android-Package': packageName,
        'X-Android-Cert': sha1,
      };
      return _cached!;
    } on PlatformException {
      return const {};
    }
  }
}
