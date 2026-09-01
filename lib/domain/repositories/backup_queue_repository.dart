import 'package:daftar/domain/entities/backup_queue_item.dart';

/// Persistence for pending Google Drive backup uploads.
abstract class BackupQueueRepository {
  /// Rows eligible for processing: `queued` or `retrying`, optional path, and
  /// `nextRetryAt` null or past.
  Future<List<BackupQueueItem>> getPendingRetryable();

  /// Inserts a new queue row (UUID `id` must be pre-generated).
  Future<void> insertItem(BackupQueueItem item);

  /// Replaces the row identified by `item.id`.
  Future<void> updateItem(BackupQueueItem item);

  /// Removes a completed or abandoned queue row.
  Future<void> deleteItem(String id);

  /// Whether any row is waiting for the user to re-authenticate with Google.
  Future<bool> anyNeedsReauth();
}
