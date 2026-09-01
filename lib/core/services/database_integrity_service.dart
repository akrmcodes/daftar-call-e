import 'package:daftar/core/errors/database_corruption_exception.dart';
import 'package:daftar/data/datasources/local/drift_database.dart';

/// Runs SQLite integrity validation before the app depends on Drift.
abstract final class DatabaseIntegrityService {
  static Future<void> assertOpen(AppDatabase database) async {
    try {
      await database.customSelect('SELECT 1').get();
    } on DatabaseCorruptionException {
      rethrow;
    } on Object catch (error) {
      if (isSqliteCorruptionError(error)) {
        throw DatabaseCorruptionException(cause: error);
      }
      rethrow;
    }
  }

  /// Returns normally when [PRAGMA integrity_check] reports `ok`.
  ///
  /// Throws [DatabaseCorruptionException] when the check fails or the
  /// database cannot be queried safely.
  static Future<void> assertHealthy(AppDatabase database) async {
    try {
      final rows = await database.customSelect('PRAGMA integrity_check').get();
      if (rows.isEmpty) {
        throw const DatabaseCorruptionException(
          detail: 'integrity_check returned no rows',
        );
      }

      for (final row in rows) {
        final value = row.read<String>('integrity_check').trim().toLowerCase();
        if (value != 'ok') {
          throw DatabaseCorruptionException(detail: value);
        }
      }

      await database.customSelect('SELECT 1').get();
    } on DatabaseCorruptionException {
      rethrow;
    } on Object catch (error) {
      if (isSqliteCorruptionError(error)) {
        throw DatabaseCorruptionException(cause: error);
      }
      rethrow;
    }
  }

  /// Heuristic for SQLite corruption errors during open or query.
  static bool isSqliteCorruptionError(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('malformed') ||
        text.contains('corrupt') ||
        text.contains('not a database') ||
        text.contains('disk image') ||
        text.contains('sqlite_corrupt');
  }
}
