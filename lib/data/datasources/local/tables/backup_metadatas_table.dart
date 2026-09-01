import 'package:daftar/domain/enums/backup_type.dart';
import 'package:drift/drift.dart';

/// Drift table definition for the `backup_metadatas` SQLite table.
///
/// Stores metadata records for completed backup operations.
/// Maps 1:1 to the domain `BackupMetadata` entity.
///
/// No sync fields — metadata is local-only and tracks backup history.
class BackupMetadatas extends Table {
  /// UUID v4 primary key.
  TextColumn get id => text()();

  /// Absolute path (local) or storage key (cloud) of the backup file.
  TextColumn get filePath => text()();

  /// Size of the backup file in bytes.
  IntColumn get sizeBytes => integer()();

  /// UTC timestamp when the backup was created.
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  /// Whether the backup is stored locally or in the cloud.
  TextColumn get type => textEnum<BackupType>()();

  /// SHA-256 hash of the backup file for integrity verification.
  TextColumn get checksum => text()();

  /// Google Drive file id when this backup was uploaded to Drive; null for local-only.
  TextColumn get googleDriveFileId => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
