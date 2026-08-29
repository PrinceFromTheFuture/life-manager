import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:shopping_list/core/util/money.dart';

/// What the parser could pull out of a receipt's OCR text. Every field is
/// nullable — a real receipt often doesn't have all of them legibly, and the
/// form takes each one only as a starting point.
///
/// The date is deliberately absent. Receipts and bank notifications routinely
/// print no year, or a two-digit one the reader cannot disambiguate, so any
/// year the model produced was a guess — and a wrong year hides the expense
/// from the month it belongs to while still moving the balance. The expense is
/// dated when you record it, and only you can change that.
class ParsedReceipt {
  const ParsedReceipt({
    this.merchant,
    this.totalAmountMinor,
    this.currency,
    this.categoryGuess,
    this.description,
  });

  final String? merchant;
  final int? totalAmountMinor;
  final String? currency;
  final String? categoryGuess;
  final String? description;
}

class ReceiptParserException implements Exception {
  ReceiptParserException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Turns raw OCR text into [ParsedReceipt] via OpenRouter's chat completions
/// endpoint. Text-only, deliberately — Vision has already done the reading;
/// this step extracts fields into a JSON schema with reasoning turned off.
class ReceiptParser {
  ReceiptParser(this._apiKey, {http.Client? client, String? model})
      : _client = client ?? http.Client(),
        _model = model ?? 'deepseek/deepseek-v4-flash';

  final String _apiKey;
  final http.Client _client;
  final String _model;

  static const String _endpoint =
      'https://openrouter.ai/api/v1/chat/completions';

  static const Duration _timeout = Duration(seconds: 20);

  static const Map<String, Object?> _receiptSchema = {
    'type': 'object',
    'properties': {
      'merchant': {
        'type': ['string', 'null']
      },
      'totalAmount': {
        'type': ['number', 'null']
      },
      'currency': {
        'type': ['string', 'null']
      },
      'categoryGuess': {
        'type': ['string', 'null']
      },
      'description': {
        'type': ['string', 'null']
      },
    },
    'required': [
      'merchant',
      'totalAmount',
      'currency',
      'categoryGuess',
      'description',
    ],
    'additionalProperties': false,
  };

  Future<ParsedReceipt> parse(String ocrText,
      {List<String> categories = const []}) async {
    if (ocrText.trim().isEmpty) {
      throw ReceiptParserException("Couldn't read that receipt.");
    }

    final categoryList = categories.isEmpty
        ? 'Groceries, Eating out, Transport, Fuel, Pharmacy, Home, Utilities, '
            'Clothing, Entertainment, Other'
        : categories.join(', ');

    final systemPrompt = '''
You extract structured expense data from OCR text of a receipt or invoice.
The text may be Hebrew, English, or mixed. Merchant names stay in their original language.
Reply with ONLY a JSON object matching the schema. No markdown, no commentary.
categoryGuess must be one of: $categoryList, or null.
totalAmount is the final total payable as a plain number, no currency symbol.
currency is a 3-letter ISO 4217 code (e.g. ILS, USD), or null.
Never report a date. The app dates the expense itself.''';

    final messages = [
      {'role': 'system', 'content': systemPrompt},
      {'role': 'user', 'content': ocrText},
    ];

    // json_schema is the contract. A few OpenRouter providers still reject
    // it; json_object is the same JSON constraint without the schema, not
    // an unconstrained retry that would spend another 20s thinking.
    var response = await _complete(messages, structured: true);
    if (response.statusCode == 400) {
      response = await _complete(messages, structured: false);
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw ReceiptParserException(
        'That API key was rejected. Check it in Settings.',
      );
    }
    if (response.statusCode == 429) {
      throw ReceiptParserException(
          'The scanner is over quota. Try again later.');
    }
    if (response.statusCode != 200) {
      throw ReceiptParserException(
        'The scanner returned an error (${response.statusCode}). '
        '${_errorSnippet(response.body)}',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, Object?>;
    final choices = decoded['choices'] as List<Object?>?;
    if (choices == null || choices.isEmpty) {
      throw ReceiptParserException('Could not read that receipt.');
    }
    final message = (choices.first as Map<String, Object?>)['message']
        as Map<String, Object?>;
    final content = _messageText(message);
    if (content == null || content.trim().isEmpty) {
      throw ReceiptParserException('Could not read that receipt.');
    }

    Map<String, Object?> fields;
    try {
      fields = jsonDecode(_stripToJson(content)) as Map<String, Object?>;
    } on FormatException {
      throw ReceiptParserException('Could not read that receipt.');
    }

    return ParsedReceipt(
      merchant: _asString(fields['merchant']),
      totalAmountMinor: _toMinor(fields['totalAmount']),
      currency: _asString(fields['currency']),
      categoryGuess: _asString(fields['categoryGuess']),
      description: _asString(fields['description']),
    );
  }

  Future<http.Response> _complete(
    List<Map<String, String>> messages, {
    required bool structured,
  }) async {
    final body = <String, Object?>{
      'model': _model,
      'messages': messages,
      'temperature': 0,
      'max_tokens': 400,
      // `exclude` still generates thinking tokens and then hides them —
      // that is what was blowing the timeout. `effort: none` turns
      // reasoning off.
      'reasoning': {
        'enabled': false,
        'effort': 'none',
      },
      'response_format': structured
          ? {
              'type': 'json_schema',
              'json_schema': {
                'name': 'parsed_receipt',
                'strict': true,
                'schema': _receiptSchema,
              },
            }
          : {'type': 'json_object'},
    };

    try {
      return await _client
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_apiKey',
              'HTTP-Referer': 'https://spindle.app',
              'X-Title': 'Spindle',
            },
            body: jsonEncode(body),
          )
          .timeout(_timeout);
    } on Exception catch (e) {
      throw ReceiptParserException(
        "Couldn't reach the scanner. Fill it in yourself, or try again when "
        "you're back online. ($e)",
      );
    }
  }

  /// Some models still wrap JSON in a code fence despite the instruction —
  /// take only the outermost braces rather than trusting the model's manners.
  static String _stripToJson(String raw) {
    final start = raw.indexOf('{');
    final end = raw.lastIndexOf('}');
    if (start == -1 || end == -1 || end < start) return raw;
    return raw.substring(start, end + 1);
  }

  /// Content can be a string, a list of parts, or empty while the useful
  /// text sits on `reasoning` — handle all three rather than giving up.
  static String? _messageText(Map<String, Object?> message) {
    final content = message['content'];
    if (content is String && content.trim().isNotEmpty) return content;
    if (content is List) {
      final buffer = StringBuffer();
      for (final part in content) {
        if (part is String) {
          buffer.write(part);
        } else if (part is Map) {
          final text = part['text'];
          if (text is String) buffer.write(text);
        }
      }
      final joined = buffer.toString();
      if (joined.trim().isNotEmpty) return joined;
    }
    final reasoning = message['reasoning'];
    if (reasoning is String && reasoning.trim().isNotEmpty) return reasoning;
    return null;
  }

  /// Totals arrive as numbers or as strings like "142.50". Both go through
  /// [Money.tryParse] so a double never enters the pipeline.
  static int? _toMinor(Object? amount) {
    if (amount == null) return null;
    if (amount is String) return Money.tryParse(amount);
    if (amount is num) return Money.tryParse(amount.toString());
    return null;
  }

  static String? _asString(Object? value) {
    if (value == null) return null;
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty || trimmed.toLowerCase() == 'null') return null;
      return trimmed;
    }
    return value.toString();
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
      // Fall through.
    }
    return body.length > 180 ? '${body.substring(0, 180)}…' : body;
  }
}
