import 'package:daftar/application/backup/ensure_drive_session.dart';
import 'package:daftar/application/backup/restore_backup_use_case.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/utils/backup_download_integrity.dart';
import 'package:daftar/domain/entities/google_drive_remote_backup_item.dart';
import 'package:daftar/domain/repositories/auth_repository.dart';
import 'package:daftar/domain/repositories/google_drive_backup_remote_repository.dart';
import 'package:fpdart/fpdart.dart';

/// Lists and restores encrypted backups from Google Drive.
///
/// [listAvailableBackups] is read-only. [restoreBackup] downloads to a temp
/// file, verifies magic header and optional SHA-256 checksum from Drive
/// metadata, then delegates decrypt + DB swap to [RestoreBackupUseCase],
/// then deletes the temp download.
class DownloadDriveBackupUseCase {
  /// Creates a download / restore orchestrator.
  const DownloadDriveBackupUseCase({
    required AuthRepository authRepository,
    required GoogleDriveBackupRemoteRepository driveRemoteRepository,
    required RestoreBackupUseCase restoreBackupUseCase,
  })  : _authRepository = authRepository,
        _driveRemoteRepository = driveRemoteRepository,
        _restoreBackupUseCase = restoreBackupUseCase;

  final AuthRepository _authRepository;
  final GoogleDriveBackupRemoteRepository _driveRemoteRepository;
  final RestoreBackupUseCase _restoreBackupUseCase;

  /// Silent re-auth then lists `.daftar` files in `appDataFolder`.
  Future<Either<Failure, List<GoogleDriveRemoteBackupItem>>>
      listAvailableBackups() async {
    final sessionResult = await ensureDriveSession(_authRepository);
    if (sessionResult case Left(value: final failure)) {
      return Left(failure);
    }

    return _driveRemoteRepository.listRemoteBackups();
  }

  /// Downloads [fileId], restores via [RestoreBackupUseCase], then cleans up.
  Future<Either<Failure, Unit>> restoreBackup(String fileId) async {
    if (fileId.trim().isEmpty) {
      return const Left(
        ValidationFailure(
          'Google Drive file id cannot be empty.',
          code: 'drive_empty_file_id',
        ),
      );
    }

    final sessionResult = await ensureDriveSession(_authRepository);
    if (sessionResult case Left(value: final failure)) {
      return Left(failure);
    }

    final metaResult = await _driveRemoteRepository.fetchRemoteBackupById(
      fileId,
    );
    final GoogleDriveRemoteBackupItem meta;
    switch (metaResult) {
      case Left(value: final failure):
        return Left(failure);
      case Right(:final value):
        meta = value;
    }

    final checksum = meta.appProperties?['checksum'] ?? '';

    final pathResult =
        await _driveRemoteRepository.downloadBackupToTemporaryFile(fileId);
    final String tempPath;
    switch (pathResult) {
      case Left(value: final failure):
        return Left(failure);
      case Right(:final value):
        tempPath = value;
    }

    final integrity = await verifyDownloadedEncryptedBackupFile(
      absolutePath: tempPath,
      expectedChecksumHex: checksum,
    );
    switch (integrity) {
      case Left(value: final failure):
        await _driveRemoteRepository.deleteIfPresent(tempPath);
        return Left(failure);
      case Right():
        break;
    }

    try {
      return await _restoreBackupUseCase.call(
        RestoreBackupParams(
          backupFilePath: tempPath,
          expectedChecksum: checksum,
        ),
      );
    } finally {
      await _driveRemoteRepository.deleteIfPresent(tempPath);
    }
  }
}
