/// Identifiers this app writes into the shared feed.
///
/// Lives in the data layer rather than next to `GroceriesApp` so the
/// repository can reference them without depending on any UI — the writer and
/// the renderer both point at these constants instead of retyping string
/// literals that can silently drift apart.
abstract final class GroceryActivity {
  /// Must match `GroceriesApp.id`; persisted in `activity.app_id`.
  static const String appId = 'groceries';

  static const String tripCompleted = 'trip_completed';

  /// Value stored in `activity.ref_table`, used to route a tap back to the
  /// trip it describes.
  static const String tripsTable = 'trips';
}
