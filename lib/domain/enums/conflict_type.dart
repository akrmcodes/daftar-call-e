/// Types of merge conflicts that can occur during multi-device sync.
///
/// Used by the Merge Engine (Stage 8.4) to classify conflicts for
/// the Smart Merge UI (Stage 9).
enum ConflictType {
  /// One device deleted an entity while another edited it.
  ///
  /// Resolution: edit survives (un-delete + audit note), but the
  /// conflict is surfaced for user awareness.
  deleteVsEdit,

  /// Two workers created the same entity (same name/key) while offline.
  ///
  /// Cannot be auto-resolved — requires user decision (merge or keep both).
  concurrentCreate,

  /// A conflict that doesn't fit neatly into other categories.
  ///
  /// Surfaced to the Smart Merge UI for manual resolution.
  ambiguous,

  /// The server permanently refused a locally recorded change.
  ///
  /// The mutation exists on this device and will never reach the workspace,
  /// so it is quarantined out of the push queue and surfaced here rather
  /// than retried forever.
  rejectedByServer,
}
