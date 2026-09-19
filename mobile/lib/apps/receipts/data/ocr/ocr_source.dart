import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'package:shopping_list/core/maps/android_api_headers.dart';

/// Something that turns a photographed receipt into text.
abstract class OcrSource {
  /// Returns the text found in [image], or an empty string if none was
  /// found. Throws [OcrException] on a network, key or quota failure — never
  /// on "no text found", which is a valid, non-exceptional result.
  Future<String> extractText(File image);
}

/// Thrown when the request to the OCR service itself fails — as opposed to
/// the request succeeding and simply finding no text.
class OcrException implements Exception {
  OcrException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Google Cloud Vision's `TEXT_DETECTION` feature, called directly over
/// REST — no server-side SDK exists for Dart, and the request is a single
/// call, so raw `http` is simpler than adding one more dependency for it.
///
/// `TEXT_DETECTION` is the fast OCR path. `DOCUMENT_TEXT_DETECTION` is the
/// dense-document model: more accurate on books, slow enough on a phone
/// photo that the request hits the timeout.
class GoogleVisionOcr implements OcrSource {
  GoogleVisionOcr(this._apiKey, {http.Client? client})
      : _client = client ?? http.Client();

  final String _apiKey;
  final http.Client _client;

  static const String _endpoint =
      'https://vision.googleapis.com/v1/images:annotate';

  static const Duration _timeout = Duration(seconds: 20);

  @override
  Future<String> extractText(File image) async {
    final bytes = await image.readAsBytes();
    final body = jsonEncode({
      'requests': [
        {
          'image': {'content': base64Encode(bytes)},
          'features': [
            {'type': 'TEXT_DETECTION'},
          ],
          // Israeli receipts are Hebrew, often mixed with English brand names
          // and Latin numerals. Without the hint, Vision guesses a Latin
          // script and returns garbage that DeepSeek cannot parse.
          'imageContext': {
            'languageHints': ['he', 'en'],
          },
        },
      ],
    });

    final headers = <String, String>{
      'Content-Type': 'application/json',
      ...await _androidHeaders(),
    };

    http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('$_endpoint?key=$_apiKey'),
            headers: headers,
            body: body,
          )
          .timeout(_timeout);
    } on Exception catch (e) {
      throw OcrException('Could not reach the scanner: $e');
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw OcrException(
        'That API key was rejected. Check it in Settings. '
        '${_errorSnippet(response.body)}',
      );
    }
    if (response.statusCode == 429) {
      throw OcrException('The scanner is over quota. Try again later.');
    }
    if (response.statusCode != 200) {
      throw OcrException(
        'The scanner returned an error (${response.statusCode}). '
        '${_errorSnippet(response.body)}',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, Object?>;
    final responses = decoded['responses'] as List<Object?>?;
    if (responses == null || responses.isEmpty) return '';

    final first = responses.first as Map<String, Object?>;
    if (first['error'] != null) {
      final error = first['error'] as Map<String, Object?>;
      throw OcrException(
        '${error['message'] ?? 'Could not read that receipt.'}',
      );
    }

    final fullText = first['fullTextAnnotation'] as Map<String, Object?>?;
    if (fullText != null) return fullText['text'] as String? ?? '';

    final annotations = first['textAnnotations'] as List<Object?>?;
    if (annotations != null && annotations.isNotEmpty) {
      final entry = annotations.first as Map<String, Object?>;
      return entry['description'] as String? ?? '';
    }
    return '';
  }

  /// Restricted Android API keys are rejected unless the request names the
  /// calling package and the signing cert. Unrestricted keys ignore these.
  static Future<Map<String, String>> _androidHeaders() async {
    try {
      return await AndroidApiHeaders.get();
    } on Exception {
      return const {};
    }
  }

  static String _errorSnippet(String body) {
    if (body.isEmpty) return '';
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['error'] is Map) {
        final message = (decoded['error'] as Map)['message'];
        if (message is String && message.isNotEmpty) return message;
      }
    } on FormatException {
      // Fall through to a truncated raw body.
    }
    return body.length > 180 ? '${body.substring(0, 180)}…' : body;
  }
}
