import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/entities/google_drive_remote_backup_item.dart';
import 'package:daftar/domain/entities/google_drive_upload_result.dart';
import 'package:fpdart/fpdart.dart';

/// Contract for Google Drive backup API operations (authenticated).
///
/// Implementations obtain a short-lived HTTP client from Google Sign-In
/// and map transport or API errors to [Failure] values.
abstract class GoogleDriveBackupRemoteRepository {
  /// Uploads an encrypted local `.daftar` file with Drive `appProperties`.
  Future<Either<Failure, GoogleDriveUploadResult>> uploadEncryptedBackup({
    required String absoluteFilePath,
    required Map<String, String> metadata,
  });

  /// Lists `.daftar` backups in `appDataFolder` (newest first).
  Future<Either<Failure, List<GoogleDriveRemoteBackupItem>>> listRemoteBackups();

  /// Loads file metadata including `appProperties` (e.g. checksum).
  Future<Either<Failure, GoogleDriveRemoteBackupItem>> fetchRemoteBackupById(
    String fileId,
  );

  /// Streams encrypted content into [destinationPath].
  Future<Either<Failure, Unit>> downloadBackupToFile({
    required String fileId,
    required String destinationPath,
  });

  /// Downloads encrypted content into a unique file under the system temp dir.
  ///
  /// Returns the absolute path for restore; callers should delete it after use.
  Future<Either<Failure, String>> downloadBackupToTemporaryFile(String fileId);

  /// Best-effort delete of a temp download path after restore.
  Future<Either<Failure, Unit>> deleteIfPresent(String absolutePath);

  /// Permanently deletes a remote `.daftar` file from `appDataFolder`.
  Future<Either<Failure, Unit>> deleteRemoteBackup(String fileId);

  /// Keeps the newest [keepNewest] remote backups; deletes older ones.
  ///
  /// Best-effort: individual delete failures are ignored so upload success
  /// is never rolled back by retention cleanup.
  Future<Either<Failure, Unit>> pruneOldRemoteBackups({
    required int keepNewest,
  });
}
