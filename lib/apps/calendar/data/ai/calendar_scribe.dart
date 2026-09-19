import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import 'package:shopping_list/apps/calendar/data/ai/calendar_plan.dart';
import 'package:shopping_list/apps/calendar/data/clock.dart';
import 'package:shopping_list/apps/calendar/data/models/place.dart';
import 'package:shopping_list/apps/calendar/data/models/place_mark.dart';
import 'package:shopping_list/apps/calendar/data/models/ticket.dart';
import 'package:shopping_list/core/design/stamp_ink.dart';

class CalendarScribeException implements Exception {
  CalendarScribeException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Turns a short request into a [CalendarPlan] via OpenRouter.
///
/// Same key and model as the receipt parser. The schema is the contract:
/// the model cannot invent registry rules, places, or free colours.
class CalendarScribe {
  CalendarScribe(this._apiKey, {http.Client? client, String? model})
      : _client = client ?? http.Client(),
        _model = model ?? 'deepseek/deepseek-v4-flash';

  final String _apiKey;
  final http.Client _client;
  final String _model;

  static const String _endpoint =
      'https://openrouter.ai/api/v1/chat/completions';

  static const Duration _timeout = Duration(seconds: 24);

  static const List<String> ops = ['create', 'adjust', 'cancel'];

  static List<String> get inkIds => [for (final ink in StampInk.all) ink.id];

  static List<String> get iconIds => [for (final mark in PlaceMark.all) mark.id];

  static const Map<String, Object?> schema = {
    'type': 'object',
    'properties': {
      'edits': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'op': {
              'type': 'string',
              'enum': ['create', 'adjust', 'cancel'],
            },
            'ticket_key': {
              'type': ['string', 'null'],
            },
            'title': {
              'type': ['string', 'null'],
            },
            'starts_at': {
              'type': ['string', 'null'],
            },
            'ends_at': {
              'type': ['string', 'null'],
            },
            'location': {
              'type': ['string', 'null'],
            },
            'note': {
              'type': ['string', 'null'],
            },
            'ink': {
              'type': ['string', 'null'],
            },
            'icon': {
              'type': ['string', 'null'],
            },
          },
          'required': [
            'op',
            'ticket_key',
            'title',
            'starts_at',
            'ends_at',
            'location',
            'note',
            'ink',
            'icon',
          ],
          'additionalProperties': false,
        },
      },
    },
    'required': ['edits'],
    'additionalProperties': false,
  };

  Future<CalendarPlan> plan({
    required String request,
    required DateTime now,
    required DateTime day,
    required List<Place> places,
    required List<Ticket> tickets,
  }) async {
    if (request.trim().isEmpty) {
      throw CalendarScribeException('Write what should change.');
    }

    final system = _systemPrompt(now: now, day: day, places: places, tickets: tickets);
    final messages = [
      {'role': 'system', 'content': system},
      {'role': 'user', 'content': request.trim()},
    ];

    var response = await _complete(messages, structured: true);
    if (response.statusCode == 400) {
      response = await _complete(messages, structured: false);
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw CalendarScribeException(
        'That API key was rejected. Check it in Settings.',
      );
    }
    if (response.statusCode == 429) {
      throw CalendarScribeException('The scribe is over quota. Try again later.');
    }
    if (response.statusCode != 200) {
      throw CalendarScribeException(
        'The scribe returned an error (${response.statusCode}).',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, Object?>;
    final choices = decoded['choices'] as List<Object?>?;
    if (choices == null || choices.isEmpty) {
      throw CalendarScribeException('Could not read that.');
    }
    final message = (choices.first as Map<String, Object?>)['message']
        as Map<String, Object?>;
    final content = _messageText(message);
    if (content == null || content.trim().isEmpty) {
      throw CalendarScribeException('Could not read that.');
    }

    Map<String, Object?> fields;
    try {
      fields = jsonDecode(_stripToJson(content)) as Map<String, Object?>;
    } on FormatException {
      throw CalendarScribeException('Could not read that.');
    }

    return parsePlan(fields);
  }

  /// Chat turn: short prose plus a ```calendar-edit fence.
  Future<CalendarReply> chat({
    required String request,
    required DateTime now,
    required DateTime day,
    required List<Place> places,
    required List<Ticket> tickets,
    List<Map<String, String>> history = const [],
  }) async {
    if (request.trim().isEmpty) {
      throw CalendarScribeException('Write what should change.');
    }

    final system = _chatPrompt(now: now, day: day, places: places, tickets: tickets);
    final messages = [
      {'role': 'system', 'content': system},
      ...history,
      {'role': 'user', 'content': request.trim()},
    ];

    final response = await _complete(
      messages,
      structured: false,
      jsonObject: false,
      maxTokens: 1200,
    );

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw CalendarScribeException(
        'That API key was rejected. Check it in Settings.',
      );
    }
    if (response.statusCode == 429) {
      throw CalendarScribeException('The scribe is over quota. Try again later.');
    }
    if (response.statusCode != 200) {
      throw CalendarScribeException(
        'The scribe returned an error (${response.statusCode}).',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, Object?>;
    final choices = decoded['choices'] as List<Object?>?;
    if (choices == null || choices.isEmpty) {
      throw CalendarScribeException('Could not read that.');
    }
    final message = (choices.first as Map<String, Object?>)['message']
        as Map<String, Object?>;
    final content = _messageText(message);
    if (content == null || content.trim().isEmpty) {
      throw CalendarScribeException('Could not read that.');
    }
    return parseReply(content);
  }

  /// Public so tests can check the fence without a network.
  static CalendarReply parseReply(String raw) {
    final fence = RegExp(
      r'```(?:calendar-edit)?\s*([\s\S]*?)```',
      caseSensitive: false,
    );
    final match = fence.firstMatch(raw);
    if (match != null) {
      final text = (raw.substring(0, match.start) + raw.substring(match.end))
          .trim();
      return CalendarReply(
        text: text,
        plan: _planFromBlob(match.group(1)!),
      );
    }
    try {
      return CalendarReply(text: '', plan: parsePlan(
        jsonDecode(_stripToJson(raw)) as Map<String, Object?>,
      ));
    } on FormatException {
      return CalendarReply(text: raw.trim(), plan: const CalendarPlan(edits: []));
    } on TypeError {
      return CalendarReply(text: raw.trim(), plan: const CalendarPlan(edits: []));
    }
  }

  static CalendarPlan _planFromBlob(String blob) {
    try {
      final decoded = jsonDecode(_stripToJson(blob));
      if (decoded is Map) {
        return parsePlan(Map<String, Object?>.from(decoded));
      }
    } on FormatException {
      // Empty plan — the prose still stands.
    }
    return const CalendarPlan(edits: []);
  }

  /// Public so tests can check the typed decode without a network.
  static CalendarPlan parsePlan(Map<String, Object?> fields) {
    final raw = fields['edits'];
    if (raw is! List) return const CalendarPlan(edits: []);
    return CalendarPlan(
      edits: [
        for (final item in raw)
          if (item is Map) _edit(Map<String, Object?>.from(item)),
      ],
    );
  }

  static CalendarEdit _edit(Map<String, Object?> m) {
    final opName = (m['op'] as String? ?? 'adjust').toLowerCase();
    final op = CalendarOp.values.firstWhere(
      (o) => o.name == opName,
      orElse: () => CalendarOp.adjust,
    );
    return CalendarEdit(
      op: op,
      ticketKey: _asString(m['ticket_key']),
      title: _asString(m['title']),
      startsAt: parseLocal(_asString(m['starts_at'])),
      endsAt: parseLocal(_asString(m['ends_at'])),
      location: _asString(m['location']),
      note: _asString(m['note']),
      ink: _known(m['ink'], inkIds),
      icon: _known(m['icon'], iconIds),
    );
  }

  static DateTime? parseLocal(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final normalised = raw.trim().replaceFirst(' ', 'T');
    final parsed = DateTime.tryParse(normalised);
    if (parsed == null) return null;
    return DateTime(
      parsed.year,
      parsed.month,
      parsed.day,
      parsed.hour,
      parsed.minute,
    );
  }

  static String _systemPrompt({
    required DateTime now,
    required DateTime day,
    required List<Place> places,
    required List<Ticket> tickets,
  }) {
    final stamp = DateFormat("yyyy-MM-dd'T'HH:mm").format;
    final placeLines = places.isEmpty
        ? '(none)'
        : places.map((p) => '- ${p.title}').join('\n');
    final ticketLines = tickets.isEmpty
        ? '(none)'
        : tickets
            .map(
              (t) =>
                  '- ${t.key}  ${t.title}  ${Clock.span(t.startsAt, t.durationMinutes)}',
            )
            .join('\n');

    return '''
You edit a personal calendar blotter. Reply with ONLY a JSON object matching the schema.
Now is ${stamp(now)}. The person is looking at ${DateFormat('yyyy-MM-dd').format(day)}.
Times are local. starts_at and ends_at are ISO-8601 without timezone, like 2026-08-29T18:00.

You may create new on-the-fly events, adjust existing tickets, or cancel them.
You MUST NOT create, edit, pause, or delete registry series, recurrences, or places.
Adjusting a series:* ticket changes that one occurrence only.

ticket_key must be copied exactly from the list, or null on create.
location must be one of the place titles below, or null. Never invent a place.
ink must be one of: ${inkIds.join(', ')}, or null.
icon must be one of: ${iconIds.join(', ')}, or null.

Places:
$placeLines

Tickets:
$ticketLines''';
  }

  static String _chatPrompt({
    required DateTime now,
    required DateTime day,
    required List<Place> places,
    required List<Ticket> tickets,
  }) {
    final stamp = DateFormat("yyyy-MM-dd'T'HH:mm").format;
    final placeLines = places.isEmpty
        ? '(none)'
        : places.map((p) => '- ${p.title}').join('\n');
    final ticketLines = tickets.isEmpty
        ? '(none)'
        : tickets
            .map(
              (t) =>
                  '- ${t.key}  ${t.title}  ${Clock.span(t.startsAt, t.durationMinutes)}',
            )
            .join('\n');

    return '''
You edit a personal calendar blotter. Reply in at most two short sentences. No greeting. No filler.
Then emit a markdown fence the app will render as a card:

```calendar-edit
{"edits":[{"op":"create|adjust|cancel","ticket_key":null,"title":null,"starts_at":null,"ends_at":null,"location":null,"note":null,"ink":null,"icon":null}]}
```

Now is ${stamp(now)}. Looking at ${DateFormat('yyyy-MM-dd').format(day)}.
Times are local. starts_at and ends_at are ISO-8601 without timezone, like 2026-08-29T18:00.

You may create on-the-fly events, adjust existing tickets, or cancel them.
You MUST NOT create, edit, pause, or delete registry series, recurrences, or places.
Adjusting a series:* ticket changes that one occurrence only.
ticket_key must be copied exactly from the list, or null on create.
location must be one of the place titles below, or null. Never invent a place.
ink must be one of: ${inkIds.join(', ')}, or null.
icon must be one of: ${iconIds.join(', ')}, or null.
If nothing should change, still emit {"edits":[]}.

Places:
$placeLines

Tickets:
$ticketLines''';
  }

  Future<http.Response> _complete(
    List<Map<String, String>> messages, {
    required bool structured,
    bool jsonObject = true,
    int maxTokens = 700,
  }) async {
    final body = <String, Object?>{
      'model': _model,
      'messages': messages,
      'temperature': 0,
      'max_tokens': maxTokens,
      'reasoning': {
        'enabled': false,
        'effort': 'none',
      },
      if (structured)
        'response_format': {
          'type': 'json_schema',
          'json_schema': {
            'name': 'calendar_plan',
            'strict': true,
            'schema': schema,
          },
        }
      else if (jsonObject)
        'response_format': {'type': 'json_object'},
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
    } on Exception {
      throw CalendarScribeException(
        "Couldn't reach the scribe. Try again when you're back online.",
      );
    }
  }

  static String _stripToJson(String raw) {
    final start = raw.indexOf('{');
    final end = raw.lastIndexOf('}');
    if (start == -1 || end == -1 || end < start) return raw;
    return raw.substring(start, end + 1);
  }

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

  static String? _known(Object? value, List<String> allowed) {
    final raw = _asString(value);
    if (raw == null) return null;
    final lower = raw.toLowerCase();
    for (final id in allowed) {
      if (id == lower) return id;
    }
    return null;
  }
}
