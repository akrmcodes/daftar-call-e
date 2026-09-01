import 'package:daftar/domain/enums/backup_type.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'backup_metadata.freezed.dart';

/// Metadata record for a completed backup operation.
///
/// Each time a backup is created (local or cloud), a [BackupMetadata]
/// record is persisted to track the backup history. This enables
/// listing available backups for restore and displaying backup status
/// in the settings screen.
///
/// Fields:
/// - [id]: UUID v4 primary key.
/// - [filePath]: Absolute path (local) or storage key (cloud) of the backup file.
/// - [sizeBytes]: Size of the backup file in bytes.
/// - [createdAt]: UTC timestamp when the backup was created.
/// - [type]: Whether the backup is stored locally or in the cloud.
/// - [checksum]: SHA-256 hash of the backup file for integrity verification.
/// - [googleDriveFileId]: Set when the backup exists on Google Drive; null for local-only.
@freezed
abstract class BackupMetadata with _$BackupMetadata {
  const factory BackupMetadata({
    required String id,
    required String filePath,
    required int sizeBytes,
    required DateTime createdAt,
    required BackupType type,
    required String checksum,
    String? googleDriveFileId,
  }) = _BackupMetadata;
}
