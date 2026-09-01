import 'package:daftar/application/auto_backup/auto_backup_policy.dart';
import 'package:daftar/application/auto_backup/auto_backup_scheduler.dart';
import 'package:daftar/application/backup/enqueue_drive_backup_upload_use_case.dart';
import 'package:daftar/application/backup/ensure_drive_session.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/services/background_backup_flight_lock.dart';
import 'package:daftar/core/services/pending_cloud_sync_store.dart';
import 'package:daftar/core/services/storage_service.dart';
import 'package:daftar/core/utils/cloud_sync_failure.dart';
import 'package:daftar/domain/constants/drive_backup_constants.dart';
import 'package:daftar/domain/entities/app_settings.dart';
import 'package:daftar/domain/entities/backup_metadata.dart';
import 'package:daftar/domain/entities/encrypted_local_backup_snapshot.dart';
import 'package:daftar/domain/entities/google_drive_upload_result.dart';
import 'package:daftar/domain/repositories/auth_repository.dart';
import 'package:daftar/domain/repositories/backup_repository.dart';
import 'package:daftar/domain/repositories/google_drive_backup_remote_repository.dart';
import 'package:daftar/domain/repositories/settings_repository.dart';
import 'package:fpdart/fpdart.dart';

/// Machine-readable code when another upload already holds the flight lock.
const String kBackupInProgressFailureCode = 'backup_in_progress';

/// Orchestrates encrypted local backup creation and Google Drive upload.
///
/// Preconditions: user must already be signed in with Google; otherwise
/// returns `AuthFailure.notSignedIn`. A silent token refresh is attempted
/// before any network I/O.
///
/// Cross-isolate [BackgroundBackupFlightLock] ensures only one encrypt+upload
/// runs at a time (prevents duplicate Drive `files.create` copies).
class UploadDriveBackupUseCase {
  /// Creates an upload orchestrator.
  const UploadDriveBackupUseCase({
    required AuthRepository authRepository,
    required SettingsRepository settingsRepository,
    required BackupRepository backupRepository,
    required GoogleDriveBackupRemoteRepository driveRemoteRepository,
    required StorageService storageService,
    required EnqueueDriveBackupUploadUseCase enqueueDriveBackupUploadUseCase,
  })  : _authRepository = authRepository,
        _settingsRepository = settingsRepository,
        _backupRepository = backupRepository,
        _driveRemoteRepository = driveRemoteRepository,
        _storageService = storageService,
        _enqueueDriveBackupUploadUseCase = enqueueDriveBackupUploadUseCase;

  final AuthRepository _authRepository;
  final SettingsRepository _settingsRepository;
  final BackupRepository _backupRepository;
  final GoogleDriveBackupRemoteRepository _driveRemoteRepository;
  final StorageService _storageService;
  final EnqueueDriveBackupUploadUseCase _enqueueDriveBackupUploadUseCase;

  /// Runs checkpoint → encrypt → write → Drive upload → metadata insert.
  Future<Either<Failure, BackupMetadata>> call() async {
    return _withFlightLock(() async {
      final authFailure = await _guardAuth();
      if (authFailure != null) {
        return authFailure;
      }

      final spaceFailure = await _guardDeviceStorage();
      if (spaceFailure != null) {
        return spaceFailure;
      }

      final snapshotResult =
          await _backupRepository.createEncryptedBackupFileOnly();
      final EncryptedLocalBackupSnapshot snapshot;
      switch (snapshotResult) {
        case Left(value: final failure):
          return Left(failure);
        case Right(:final value):
          snapshot = value;
      }

      return _uploadSnapshot(snapshot);
    });
  }

  /// Uploads an existing encrypted `.daftar` at [absolutePath] (queue resume).
  Future<Either<Failure, BackupMetadata>> resumeFromEncryptedFilePath(
    String absolutePath,
  ) async {
    return _withFlightLock(() async {
      final authFailure = await _guardAuth();
      if (authFailure != null) {
        return authFailure;
      }

      final spaceFailure = await _guardDeviceStorage();
      if (spaceFailure != null) {
        return spaceFailure;
      }

      final snapshotResult = await _backupRepository
          .buildSnapshotFromEncryptedBackupFile(absolutePath);
      final EncryptedLocalBackupSnapshot snapshot;
      switch (snapshotResult) {
        case Left(value: final failure):
          return Left(failure);
        case Right(:final value):
          snapshot = value;
      }

      return _uploadSnapshot(snapshot);
    });
  }

  Future<Either<Failure, BackupMetadata>> _withFlightLock(
    Future<Either<Failure, BackupMetadata>> Function() action,
  ) async {
    final owner = await BackgroundBackupFlightLock.tryAcquire();
    if (owner == null) {
      return const Left(
        ValidationFailure(
          'A Drive backup upload is already in progress.',
          code: kBackupInProgressFailureCode,
        ),
      );
    }
    try {
      return await action();
    } finally {
      await BackgroundBackupFlightLock.release(owner);
    }
  }

  Future<Either<Failure, BackupMetadata>?> _guardAuth() async {
    final sessionResult = await ensureDriveSession(_authRepository);
    return sessionResult.fold(
      Left.new,
      (_) => null,
    );
  }

  Future<Either<Failure, BackupMetadata>?> _guardDeviceStorage() async {
    final hasSpace = await _storageService.hasEnoughSpace();
    if (hasSpace) {
      return null;
    }
    return const Left(StorageFullFailure());
  }

  Future<Either<Failure, BackupMetadata>> _uploadSnapshot(
    EncryptedLocalBackupSnapshot snapshot,
  ) async {
    final settingsResult = await _settingsRepository.get();
    final AppSettings settings;
    switch (settingsResult) {
      case Left(value: final failure):
        return Left(failure);
      case Right(:final value):
        settings = value;
    }

    final email = settings.googleAccountEmail;
    final metadata = <String, String>{
      'appVersion': DriveBackupConstants.appVersionLabel,
      'schemaVersion': DriveBackupConstants.schemaVersion.toString(),
      'checksum': snapshot.checksum,
      'backupTimestamp': snapshot.createdAtUtc.toIso8601String(),
      if (email != null && email.isNotEmpty) 'googleAccountEmail': email,
    };

    final uploadResult = await _driveRemoteRepository.uploadEncryptedBackup(
      absoluteFilePath: snapshot.filePath,
      metadata: metadata,
    );
    final GoogleDriveUploadResult uploaded;
    switch (uploadResult) {
      case Left(value: final failure):
        if (isTransientCloudSyncFailure(failure)) {
          await _enqueueDriveBackupUploadUseCase.call(
            encryptedBackupPath: snapshot.filePath,
          );
        }
        return Left(failure);
      case Right(:final value):
        uploaded = value;
    }

    final insertResult = await _backupRepository.insertGoogleDriveBackupRecord(
      snapshot: snapshot,
      googleDriveFileId: uploaded.fileId,
    );

    if (insertResult case Right(value: final metadata)) {
      await PendingCloudSyncStore.clear();
      await _settingsRepository.update(
        UpdateSettingsParams(
          lastBackupAt: metadata.createdAt,
          clearLastAutoBackupFailure: true,
          lastAutoBackupOutcome: 'success',
        ),
      );
      // Best-effort retention — never fail the upload on prune errors.
      await _driveRemoteRepository.pruneOldRemoteBackups(
        keepNewest: DriveBackupConstants.maxRetainedDriveBackups,
      );
      // Align Android chain to last success + full interval.
      if (settings.driveAutoBackupEnabled) {
        await AutoBackupScheduler.scheduleNextRun(
          interval: AutoBackupPolicy.intervalFor(settings),
          settings: settings,
        );
      }
    }

    return insertResult;
  }
}
