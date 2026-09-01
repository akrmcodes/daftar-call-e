import 'package:daftar/core/constants/app_constants.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/services/storage_service.dart';
import 'package:daftar/domain/repositories/backup_repository.dart';
import 'package:fpdart/fpdart.dart';

/// Parameters required for the backup restore operation.
///
/// `backupFilePath` is the absolute path to the encrypted `.daftar` file.
/// `expectedChecksum` is the SHA-256 hex digest of the encrypted file,
/// recorded in the `BackupMetadata.checksum` field when the backup was
/// created.
class RestoreBackupParams {
  const RestoreBackupParams({
    required this.backupFilePath,
    this.expectedChecksum = '',
  });

  final String backupFilePath;

  /// The SHA-256 hex digest of the encrypted backup file.
  ///
  /// When restoring from the backup history list, this is the checksum
  /// recorded at creation time. When restoring from an external file
  /// picked via file_picker, this is empty — integrity is enforced by
  /// the GCM authentication tag during decryption.
  final String expectedChecksum;
}

/// Restores the active database from an encrypted `.daftar` backup file.
///
/// ## WARNING — DESTRUCTIVE OPERATION
///
/// This is the most dangerous operation in the app. It replaces the
/// live SQLite database with data from the backup file. Once the
/// database connection is closed and the file is swapped, the app
/// MUST be restarted to establish a new Drift connection.
///
/// ## Business Rules
/// - No free-tier gating — local restore is available to all users.
/// - The backup file's SHA-256 checksum MUST match the expected checksum
///   before any decryption is attempted.
/// - Decryption, checksum validation, WAL cleanup, and the atomic file
///   swap are delegated to [BackupRepository.restoreLocal], which
///   handles the full validate → decrypt → close → delete WAL/SHM →
///   swap pipeline.
///
/// ## Chain-of-thought: Restore Sequence
/// 1. Validate that `backupFilePath` and `expectedChecksum` are non-empty.
/// 2. Delegate to [BackupRepository.restoreLocal] which:
///    a. Reads the encrypted backup bytes from disk.
///    b. Computes SHA-256 and compares to the expected checksum.
///    c. Reads the `DFTR` magic header and version byte to resolve
///       the correct app-bound AES-256 key (stateless — no storage).
///    d. Decrypts in an isolate (AES-256-GCM: bytes 5–20 = IV,
///       remainder = ciphertext with embedded GCM auth tag).
///    e. Writes decrypted bytes to a staging temp file.
///    f. **POINT OF NO RETURN:** closes the active DB connection.
///    g. Deletes `-wal` and `-shm` files (CRITICAL for SQLite integrity).
///    h. Renames the temp file to become the new database.
/// 3. Return success. The UI layer MUST force an app restart.
///
/// ## Post-Restore: App Restart Requirement
///
/// After a successful restore, the Drift `AppDatabase` connection is
/// closed and the physical file has been replaced. No further database
/// operations are possible. The calling UI MUST force a full app
/// restart using one of these strategies:
/// - `SystemNavigator.pop()` to terminate the process (Android).
/// - Full Riverpod `ProviderContainer` invalidation + re-bootstrap.
/// - `exit(0)` as a last resort (not recommended on iOS).
///
/// ## Failure Modes
///
/// Returns `Left<Failure>` on error:
/// - [ValidationFailure] if inputs are empty or the SHA-256 checksum
///   does not match (file corrupted or tampered).
/// - [StorageFullFailure] if device free space is below
///   [AppConstants.minFreeStorageMegabytes].
/// - [StorageFailure] if decryption fails (wrong key, tampered
///   ciphertext, I/O error).
/// - [StorageFailure] if the file swap fails (disk full, permission
///   denied).
///
/// Returns `Right<Unit>` on success. The app must be restarted.
class RestoreBackupUseCase {
  /// Creates a [RestoreBackupUseCase] with the given dependencies.
  const RestoreBackupUseCase(
    this._backupRepository,
    this._storageService,
  );

  final BackupRepository _backupRepository;
  final StorageService _storageService;

  /// Executes the backup restore flow.
  ///
  /// Preconditions:
  /// - `backupFilePath` must point to a valid encrypted `.daftar` file.
  /// - `expectedChecksum` must be the SHA-256 hex digest recorded
  ///   at backup creation time.
  ///
  /// Returns `Right<Unit>` on success, or `Left<Failure>`:
  /// - [ValidationFailure] if inputs are invalid or checksum mismatches.
  /// - [StorageFailure] if decryption or file I/O fails.
  Future<Either<Failure, Unit>> call(RestoreBackupParams params) async {
    if (params.backupFilePath.trim().isEmpty) {
      return const Left(
        ValidationFailure(
          'Backup file path cannot be empty.',
          code: 'restore_empty_path',
        ),
      );
    }

    final hasSpace = await _storageService.hasEnoughSpace();
    if (!hasSpace) {
      return const Left(StorageFullFailure());
    }

    return _backupRepository.restoreLocal(
      params.backupFilePath,
      expectedChecksum: params.expectedChecksum,
    );
  }
}
