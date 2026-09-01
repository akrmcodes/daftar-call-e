import 'package:daftar/data/datasources/local/drift_database.dart' as db;
import 'package:daftar/domain/entities/backup_queue_item.dart';
import 'package:daftar/domain/enums/backup_queue_status.dart';
import 'package:drift/drift.dart';

/// Maps Drift `drive_backup_queue_rows` rows to domain `BackupQueueItem`.
extension DriveBackupQueueRowMapper on db.DriveBackupQueueRow {
  BackupQueueItem toDomain() => BackupQueueItem(
        id: id,
        status: backupQueueStatusFromWire(status),
        backupMetadataId: backupMetadataId,
        pendingBackupFilePath: pendingBackupFilePath,
        lastBackupAttemptAt: lastBackupAttemptAt,
        backupRetryCount: backupRetryCount,
        nextRetryAt: nextRetryAt,
      );
}

/// Maps a domain `BackupQueueItem` to a Drift companion for insert/replace.
extension BackupQueueItemCompanionMapper on BackupQueueItem {
  db.DriveBackupQueueRowsCompanion toCompanion() =>
      db.DriveBackupQueueRowsCompanion.insert(
        id: id,
        status: status.toWire(),
        backupMetadataId: Value(backupMetadataId),
        pendingBackupFilePath: Value(pendingBackupFilePath),
        lastBackupAttemptAt: Value(lastBackupAttemptAt),
        backupRetryCount: Value(backupRetryCount),
        nextRetryAt: Value(nextRetryAt),
      );

  /// Companion for partial updates (must set every column explicitly).
  db.DriveBackupQueueRowsCompanion toUpdateCompanion() =>
      db.DriveBackupQueueRowsCompanion(
        id: Value(id),
        status: Value(status.toWire()),
        backupMetadataId: Value(backupMetadataId),
        pendingBackupFilePath: Value(pendingBackupFilePath),
        lastBackupAttemptAt: Value(lastBackupAttemptAt),
        backupRetryCount: Value(backupRetryCount),
        nextRetryAt: Value(nextRetryAt),
      );
}

BackupQueueStatus backupQueueStatusFromWire(String raw) {
  return switch (raw) {
    'retrying' => BackupQueueStatus.retrying,
    'needsReauth' => BackupQueueStatus.needsReauth,
    'failed' => BackupQueueStatus.failed,
    _ => BackupQueueStatus.queued,
  };
}

extension BackupQueueStatusWire on BackupQueueStatus {
  String toWire() => switch (this) {
        BackupQueueStatus.queued => 'queued',
        BackupQueueStatus.retrying => 'retrying',
        BackupQueueStatus.needsReauth => 'needsReauth',
        BackupQueueStatus.failed => 'failed',
      };
}
