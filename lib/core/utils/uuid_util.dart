import 'package:uuid/uuid.dart';

/// Utility for generating UUID v4 identifiers.
///
/// All primary keys in Daftar use UUID v4 (random) to ensure
/// unique IDs across devices without requiring a central authority.
/// This is essential for offline-first operation where auto-increment
/// IDs would conflict during sync.
abstract final class UuidUtil {
  static const Uuid _uuid = Uuid();

  /// Generates a new random UUID v4 string.
  ///
  /// Example: `'550e8400-e29b-41d4-a716-446655440000'`
  static String generate() => _uuid.v4();
}
