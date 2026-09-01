import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/entities/backup_metadata.dart';
import 'package:daftar/domain/entities/encrypted_local_backup_snapshot.dart';
import 'package:daftar/domain/enums/backup_type.dart';
import 'package:fpdart/fpdart.dart';

/// Contract for backup and restore operations.
///
/// Implementations must:
/// - Encrypt backup files using AES-256 before storage.
/// - Verify checksum integrity on restore.
/// - Run encryption/decryption in a Dart isolate.
/// - Return [Left(StorageFailure)] for file system errors.
/// - Return [Left(NetworkFailure)] for cloud operation errors.
/// - Persist [BackupMetadata] after successful backup creation.
abstract class BackupRepository {
  /// Creates an encrypted local backup of the entire database.
  ///
  /// The backup file is saved to the app's document directory.
  /// Encryption uses an app-bound AES-256 key delivered via build-time
  /// obfuscation (envied). The key is resolved based
  /// on the backup format version — the pipeline is entirely stateless.
  ///
  /// Returns [Left(StorageFailure)] if encryption or file write fails.
  Future<Either<Failure, BackupMetadata>> createLocal();

  /// Creates an encrypted `.daftar` snapshot on disk without inserting metadata.
  ///
  /// Used by Google Drive upload flows that persist metadata only after a
  /// successful remote upload.
  Future<Either<Failure, EncryptedLocalBackupSnapshot>>
      createEncryptedBackupFileOnly();

  /// Persists a `BackupMetadata` row for a Google Drive backup.
  ///
  /// The encrypted file must already exist at the snapshot's `filePath`.
  Future<Either<Failure, BackupMetadata>> insertGoogleDriveBackupRecord({
    required EncryptedLocalBackupSnapshot snapshot,
    required String googleDriveFileId,
  });

  /// Builds a snapshot from an existing encrypted `.daftar` on disk.
  ///
  /// Used when resuming a queued Drive upload from [absolutePath].
  Future<Either<Failure, EncryptedLocalBackupSnapshot>>
      buildSnapshotFromEncryptedBackupFile(String absolutePath);

  /// Restores the database from a local encrypted backup file.
  ///
  /// Steps:
  /// 1. Verify SHA-256 checksum of encrypted file against [expectedChecksum]
  /// 2. Decrypt the backup file
  /// 3. Replace the current database atomically
  ///
  /// Returns [Left(ValidationFailure)] if checksum does not match.
  /// Returns [Left(StorageFailure)] if decryption, checksum, or
  /// file read fails.
  Future<Either<Failure, Unit>> restoreLocal(
    String filePath, {
    required String expectedChecksum,
  });

  /// Uploads an encrypted backup file to Supabase Storage.
  ///
  /// Requires Supabase authentication. Creates a local backup first
  /// if none exists, then uploads.
  ///
  /// Returns [Left(NetworkFailure)] if upload fails.
  /// Returns [Left(AuthFailure)] if not authenticated.
  Future<Either<Failure, BackupMetadata>> uploadCloud();

  /// Downloads and restores a backup from Supabase Storage.
  ///
  /// Downloads the encrypted file, then delegates to the local
  /// restore flow.
  ///
  /// Returns [Left(NetworkFailure)] if download fails.
  /// Returns [Left(AuthFailure)] if not authenticated.
  Future<Either<Failure, Unit>> downloadCloud(String backupId);

  /// Lists all available backups (both local and cloud).
  ///
  /// Returns backup metadata sorted by creation date (newest first).
  Future<Either<Failure, List<BackupMetadata>>> listBackups({
    BackupType? filterType,
  });

  /// Deletes a backup record and its physical file from disk.
  ///
  /// Returns [Left(StorageFailure)] if the file cannot be deleted.
  /// Returns [Left(DatabaseFailure)] if the metadata row cannot be removed.
  Future<Either<Failure, Unit>> deleteBackup(String id);
}
