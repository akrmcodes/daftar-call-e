import 'package:daftar/core/constants/app_constants.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/services/storage_service.dart';
import 'package:daftar/domain/entities/backup_metadata.dart';
import 'package:daftar/domain/repositories/backup_repository.dart';
import 'package:fpdart/fpdart.dart';

/// Creates an encrypted local backup of the entire Drift database.
///
/// ## Business Rules
/// - Local backup is available to ALL users (free and premium).
///   No tier gating is applied at this level.
/// - The database WAL is checkpointed before file extraction to
///   guarantee a consistent on-disk snapshot (no partial transactions).
/// - The database bytes are encrypted with AES-256-GCM before being
///   written to the backup directory. The encryption key is an
///   app-bound constant delivered via `envied` build-time obfuscation.
///   The pipeline is stateless — no key storage, no key loss on
///   uninstall or device migration.
/// - A [BackupMetadata] record is persisted to the database after the
///   backup file is written, recording the file path, size, timestamp,
///   and SHA-256 checksum of the encrypted payload.
///
/// ## Use-Case chain-of-thought
/// 1. Validate that backup creation can proceed (currently no-op;
///    reserved for disk-space and precondition checks).
/// 2. Delegate to [BackupRepository.createLocal] which:
///    a. Checkpoints the WAL.
///    b. Reads raw DB bytes.
///    c. Encrypts them in an isolate.
///    d. Writes the `.daftar` file.
///    e. Persists [BackupMetadata].
/// 3. Return the [BackupMetadata] on success so the UI can display
///    the new entry immediately.
///
/// ## Failure modes
/// Returns [Left<Failure>] on any error:
/// - [StorageFullFailure] if device free space is below
///   [AppConstants.minFreeStorageMegabytes].
/// - [StorageFailure] if the WAL checkpoint, file read, encryption,
///   or file write fails.
/// - [DatabaseFailure] if persisting [BackupMetadata] fails.
///
/// Returns [Right<BackupMetadata>] on success.
class CreateLocalBackupUseCase {
  /// Creates a [CreateLocalBackupUseCase] with the given dependencies.
  const CreateLocalBackupUseCase(
    this._backupRepository,
    this._storageService,
  );

  final BackupRepository _backupRepository;
  final StorageService _storageService;

  /// Executes the local backup creation flow.
  ///
  /// Preconditions: the database must be open and the app must have
  /// write access to the documents directory.
  ///
  /// Returns [Right<BackupMetadata>] on success, or [Left<Failure>]:
  /// - [StorageFailure] for any I/O or encryption error.
  /// - [DatabaseFailure] if saving the backup metadata record fails.
  Future<Either<Failure, BackupMetadata>> call() async {
    final hasSpace = await _storageService.hasEnoughSpace();
    if (!hasSpace) {
      return const Left(StorageFullFailure());
    }

    // Delegate the full checkpoint → encrypt → write → persist
    // pipeline to the repository. All file I/O and crypto exceptions
    // are caught and mapped to Failure types inside the repository.
    return _backupRepository.createLocal();
  }
}
