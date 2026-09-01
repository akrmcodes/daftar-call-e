import 'package:drift/drift.dart';

/// Drift table for pending Google Drive backup uploads.
///
/// Row class is generated as `DriveBackupQueueRow` to avoid clashing with the
/// domain `BackupQueueItem` entity.
@TableIndex(name: 'idx_drive_backup_queue_status_next', columns: {#status, #nextRetryAt})
class DriveBackupQueueRows extends Table {
  /// UUID v4 primary key.
  TextColumn get id => text()();

  /// Optional link to `backup_metadatas.id` when known.
  TextColumn get backupMetadataId => text().nullable()();

  /// Absolute path to the encrypted `.daftar` file awaiting upload.
  TextColumn get pendingBackupFilePath => text().nullable()();

  /// One of: `queued`, `retrying`, `needsReauth`, `failed`.
  TextColumn get status => text()();

  /// UTC time of the last upload attempt, if any.
  DateTimeColumn get lastBackupAttemptAt => dateTime().nullable()();

  /// Number of failed upload attempts so far.
  IntColumn get backupRetryCount =>
      integer().withDefault(const Constant(0))();

  /// Earliest UTC time the scheduler may attempt again.
  DateTimeColumn get nextRetryAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
