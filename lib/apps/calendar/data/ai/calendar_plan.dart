import 'dart:convert';

/// What the scribe is allowed to do to the blotter.
///
/// Registry series are out of reach. These ops only write blocks and
/// this-time overrides.
enum CalendarOp { create, adjust, cancel }

/// One typed edit the model returned. Null fields mean "leave as is".
class CalendarEdit {
  const CalendarEdit({
    required this.op,
    this.ticketKey,
    this.title,
    this.startsAt,
    this.endsAt,
    this.location,
    this.note,
    this.ink,
    this.icon,
  });

  final CalendarOp op;
  final String? ticketKey;
  final String? title;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final String? location;
  final String? note;
  final String? ink;
  final String? icon;

  int? durationMinutes({int fallback = 60}) {
    final start = startsAt;
    final end = endsAt;
    if (start == null || end == null) return null;
    final minutes = end.difference(start).inMinutes;
    return minutes < 15 ? 15 : minutes;
  }
}

class CalendarPlan {
  const CalendarPlan({required this.edits});

  final List<CalendarEdit> edits;

  bool get isEmpty => edits.isEmpty;

  /// Markdown the chat paints as an artifact card — same fence the model
  /// is asked to emit, so a stored turn and a live one render identically.
  String toFence() {
    final edits = [
      for (final edit in this.edits)
        {
          'op': edit.op.name,
          if (edit.ticketKey != null) 'ticket_key': edit.ticketKey,
          if (edit.title != null) 'title': edit.title,
          if (edit.startsAt != null)
            'starts_at': _stamp(edit.startsAt!),
          if (edit.endsAt != null) 'ends_at': _stamp(edit.endsAt!),
          if (edit.location != null) 'location': edit.location,
          if (edit.note != null) 'note': edit.note,
          if (edit.ink != null) 'ink': edit.ink,
          if (edit.icon != null) 'icon': edit.icon,
        },
    ];
    return '```calendar-edit\n${jsonEncode({'edits': edits})}\n```';
  }

  static String _stamp(DateTime when) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${when.year}-${two(when.month)}-${two(when.day)}T'
        '${two(when.hour)}:${two(when.minute)}';
  }
}

/// One assistant turn: a short line, then the typed edits that will be written.
class CalendarReply {
  const CalendarReply({required this.text, required this.plan});

  final String text;
  final CalendarPlan plan;
}

class ApplyResult {
  const ApplyResult({
    this.created = 0,
    this.adjusted = 0,
    this.cancelled = 0,
    this.ignored = 0,
  });

  final int created;
  final int adjusted;
  final int cancelled;
  final int ignored;

  int get changed => created + adjusted + cancelled;

  String get message {
    if (changed == 0) return 'Nothing to change.';
    final parts = <String>[
      if (created == 1) 'Added 1',
      if (created > 1) 'Added $created',
      if (adjusted == 1) 'moved 1',
      if (adjusted > 1) 'moved $adjusted',
      if (cancelled == 1) 'cancelled 1',
      if (cancelled > 1) 'cancelled $cancelled',
    ];
    final lead = parts.isEmpty ? 'Updated' : parts.join(', ');
    return '${lead[0].toUpperCase()}${lead.substring(1)}.';
  }
}
