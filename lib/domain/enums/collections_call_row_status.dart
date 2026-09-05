/// Per-recipient CALL-E progress on the Collections Desk.
///
/// Matches HUD vocabulary. Never `delivered` or `paid`.
enum CollectionsCallRowStatus {
  /// Queued for dial (local seed before run-batch).
  planned,

  /// CALL-E reports ringing.
  ringing,

  /// Terminal success (promise captured or call ended).
  completed,

  /// Terminal failure or needs human.
  failed,
}
