/// Thrown when the on-disk SQLite database fails [PRAGMA integrity_check]
/// or cannot be opened without corruption errors.
///
/// Caught at app startup to route merchants to the database recovery screen
/// instead of the main router.
class DatabaseCorruptionException implements Exception {
  /// Creates a [DatabaseCorruptionException] with an optional [cause].
  const DatabaseCorruptionException({this.cause, this.detail});

  final Object? cause;

  /// Human-readable integrity detail (never shown raw in UI).
  final String? detail;

  @override
  String toString() {
    final buffer = StringBuffer('DatabaseCorruptionException');
    if (detail != null) {
      buffer.write(': $detail');
    }
    if (cause != null) {
      buffer.write(' ($cause)');
    }
    return buffer.toString();
  }
}
