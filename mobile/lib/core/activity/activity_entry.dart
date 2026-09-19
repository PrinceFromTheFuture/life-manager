/// One thing that happened, in any mini-app.
///
/// The hub feed is built entirely from these, which is what lets it show a
/// unified timeline without knowing that "expenses" or "shopping trips" exist.
///
/// [title], [subtitle] and [amountMinor] are denormalised copies of whatever
/// the owning app wants shown. That is deliberate: the feed renders a whole
/// screen of rows from a single query, with no per-row lookup into whichever
/// app produced them. The cost is that a copy can drift from its source, which
/// is contained by writing entries through `ActivityWriter` inside the same
/// transaction as the change they describe.
class ActivityEntry {
  const ActivityEntry({
    this.id,
    required this.appId,
    required this.kind,
    required this.title,
    this.subtitle,
    this.amountMinor,
    required this.occurredAt,
    this.refTable,
    this.refId,
  });

  final int? id;

  /// Which mini-app this belongs to. Matches `MiniApp.id`, and is how the feed
  /// knows which module to hand the row back to for rendering.
  final String appId;

  /// App-defined discriminator, e.g. `trip_completed`, `expense_added`. The
  /// hub never inspects this — only the owning app does.
  final String kind;

  final String title;
  final String? subtitle;

  /// Optional money, in minor units. Rendered in mono by the owning app.
  final int? amountMinor;

  final DateTime occurredAt;

  /// Where the real record lives, so a tap can open it.
  final String? refTable;
  final int? refId;

  factory ActivityEntry.fromMap(Map<String, Object?> m) => ActivityEntry(
        id: m['id'] as int?,
        appId: m['app_id']! as String,
        kind: m['kind']! as String,
        title: m['title']! as String,
        subtitle: m['subtitle'] as String?,
        amountMinor: m['amount_minor'] as int?,
        occurredAt:
            DateTime.fromMillisecondsSinceEpoch(m['occurred_at']! as int),
        refTable: m['ref_table'] as String?,
        refId: m['ref_id'] as int?,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'app_id': appId,
        'kind': kind,
        'title': title,
        'subtitle': subtitle,
        'amount_minor': amountMinor,
        'occurred_at': occurredAt.millisecondsSinceEpoch,
        'ref_table': refTable,
        'ref_id': refId,
      };
}

/// Entries for one calendar day, which is the unit the hub feed is grouped by.
class ActivityDay {
  const ActivityDay({required this.date, required this.entries});

  final DateTime date;
  final List<ActivityEntry> entries;
}
