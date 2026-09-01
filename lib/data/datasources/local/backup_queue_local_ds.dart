import 'package:daftar/data/datasources/local/drift_database.dart' as db;
import 'package:daftar/data/mappers/backup_queue_mapper.dart';
import 'package:daftar/domain/entities/backup_queue_item.dart';
import 'package:drift/drift.dart';

/// Drift-backed access to the Drive backup upload queue.
class BackupQueueLocalDs {
  /// Creates a data source bound to the app database.
  BackupQueueLocalDs(this._database);

  final db.AppDatabase _database;

  /// Rows ready to process: `queued` or `retrying`, path set, and
  /// `nextRetryAt` absent or in the past.
  Future<List<db.DriveBackupQueueRow>> getPendingRetryable() {
    final now = DateTime.now().toUtc();
    return (_database.select(_database.driveBackupQueueRows)
          ..where((t) => t.pendingBackupFilePath.isNotNull())
          ..where(
            (t) =>
                t.nextRetryAt.isNull() |
                t.nextRetryAt.isSmallerOrEqualValue(now),
          )
          ..where((t) => t.status.isIn(['queued', 'retrying'])))
        .get();
  }

  /// Inserts a new queue row.
  Future<void> insertItem(BackupQueueItem item) async {
    await _database
        .into(_database.driveBackupQueueRows)
        .insert(item.toCompanion(), mode: InsertMode.insertOrFail);
  }

  /// Replaces all columns for the row identified by `item.id`.
  Future<void> updateItem(BackupQueueItem item) async {
    await (_database.update(_database.driveBackupQueueRows)
          ..where((t) => t.id.equals(item.id)))
        .write(item.toUpdateCompanion());
  }

  /// Deletes the row with the given id.
  Future<void> deleteItem(String id) async {
    await (_database.delete(_database.driveBackupQueueRows)
          ..where((t) => t.id.equals(id)))
        .go();
  }

  /// Removes every pending Drive upload row.
  ///
  /// Used when the signed-in Google account changes so queued uploads are not
  /// delivered to the wrong Drive account.
  Future<void> clearAll() async {
    await _database.delete(_database.driveBackupQueueRows).go();
  }

  /// True if at least one row is in `needsReauth` state.
  Future<bool> anyNeedsReauth() async {
    final rows = await (_database.select(_database.driveBackupQueueRows)
          ..where((t) => t.status.equals('needsReauth'))
          ..limit(1))
        .get();
    return rows.isNotEmpty;
  }
}
