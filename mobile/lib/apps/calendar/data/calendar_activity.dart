/// Identifiers the calendar app writes into the shared feed.
abstract final class CalendarActivity {
  /// Must match `CalendarApp.id`; persisted in `activity.app_id`.
  static const String appId = 'calendar';

  static const String blockAdded = 'block_added';
  static const String seriesAdded = 'series_added';

  static const String blocksTable = 'calendar_blocks';
  static const String seriesTable = 'calendar_series';
  static const String locationsTable = 'calendar_locations';
  static const String overridesTable = 'calendar_overrides';
}
