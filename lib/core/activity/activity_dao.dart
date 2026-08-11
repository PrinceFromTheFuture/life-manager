import 'package:sqflite/sqflite.dart';

import 'package:shopping_list/core/activity/activity_entry.dart';

/// Reads the cross-app feed.
class ActivityDao {
  ActivityDao(this._db);

  final DatabaseExecutor _db;

  Future<List<ActivityEntry>> recent({int limit = 200}) async {
    final rows = await _db.query(
      'activity',
      orderBy: 'occurred_at DESC, id DESC',
      limit: limit,
    );
    return rows.map(ActivityEntry.fromMap).toList();
  }

  /// The feed grouped into calendar days, newest first.
  ///
  /// Grouped in Dart rather than SQL because "which day is this" is a
  /// local-timezone question, and SQLite would answer it in UTC — putting late
  /// evening entries on tomorrow's date.
  Future<List<ActivityDay>> recentByDay({int limit = 200}) async {
    final entries = await recent(limit: limit);
    final days = <DateTime, List<ActivityEntry>>{};

    for (final entry in entries) {
      final local = entry.occurredAt.toLocal();
      final key = DateTime(local.year, local.month, local.day);
      days.putIfAbsent(key, () => []).add(entry);
    }

    final ordered = days.keys.toList()..sort((a, b) => b.compareTo(a));
    return [
      for (final date in ordered)
        ActivityDay(date: date, entries: days[date]!),
    ];
  }
}

/// Writes to the cross-app feed.
///
/// Takes a [DatabaseExecutor] rather than a [Database] specifically so it can
/// be handed a transaction. Every entry must be written in the same
/// transaction as the change it describes — otherwise a failure between the
/// two leaves the feed claiming something happened that didn't, or silently
/// missing something that did.
class ActivityWriter {
  const ActivityWriter(this._db);

  final DatabaseExecutor _db;

  Future<int> write(ActivityEntry entry) =>
      _db.insert('activity', entry.toMap());

  /// Removes the feed entries pointing at a record that is being deleted.
  Future<void> deleteFor({
    required String appId,
    required String refTable,
    required int refId,
  }) =>
      _db.delete(
        'activity',
        where: 'app_id = ? AND ref_table = ? AND ref_id = ?',
        whereArgs: [appId, refTable, refId],
      );
}
