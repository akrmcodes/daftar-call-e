import 'dart:io';

import 'package:daftar/application/backup/download_drive_backup_use_case.dart';
import 'package:daftar/application/backup/restore_backup_use_case.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/recovery/recovery_auth_repository.dart';
import 'package:daftar/core/services/storage_service.dart';
import 'package:daftar/data/datasources/local/backup_local_ds.dart';
import 'package:daftar/data/repositories/backup_repository_impl.dart';
import 'package:daftar/data/repositories/google_drive_backup_remote_repository_impl.dart';
import 'package:daftar/domain/entities/google_drive_remote_backup_item.dart';
import 'package:fpdart/fpdart.dart';
import 'package:path_provider/path_provider.dart';

/// Headless backup restore used when the main DB cannot boot.
///
/// Supports local `.daftar` files and Google Drive `appDataFolder` backups.
/// Does not require the main app database to be open.
class DatabaseRecoveryCoordinator {
  final RecoveryAuthRepository _recoveryAuth = RecoveryAuthRepository.create();

  /// Lists encrypted backups in the user's Drive app data folder.
  Future<Either<Failure, List<GoogleDriveRemoteBackupItem>>>
      listDriveBackups() async {
    return _buildDownloadUseCase().listAvailableBackups();
  }

  /// Downloads [fileId] from Drive and swaps the on-disk SQLite file.
  Future<Either<Failure, Unit>> restoreFromDrive(String fileId) async {
    return _buildDownloadUseCase().restoreBackup(fileId);
  }

  /// Restores the on-disk SQLite database from a local `.daftar` file.
  Future<Either<Failure, Unit>> restoreFromLocalFile(
    String filePath, {
    String expectedChecksum = '',
  }) async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final backupLocalDs = BackupLocalDs.fileOnly(
      documentsDirectoryResolver: () async => documentsDirectory,
    );

    final restoreUseCase = RestoreBackupUseCase(
      BackupRepositoryImpl(backupLocalDs: backupLocalDs),
      StorageService(),
    );

    return restoreUseCase.call(
      RestoreBackupParams(
        backupFilePath: filePath,
        expectedChecksum: expectedChecksum,
      ),
    );
  }

  /// Verifies that [filePath] exists and has a `.daftar` extension.
  Either<Failure, File> validateBackupFile(String filePath) {
    final file = File(filePath);
    if (!file.existsSync()) {
      return const Left(
        StorageFailure(
          'Backup file was not found.',
          code: 'recovery_file_missing',
        ),
      );
    }
    if (!filePath.toLowerCase().endsWith('.daftar')) {
      return const Left(
        ValidationFailure(
          'Please select a valid .daftar backup file.',
          code: 'recovery_invalid_extension',
        ),
      );
    }
    return Right(file);
  }

  DownloadDriveBackupUseCase _buildDownloadUseCase() {
    final (googleAuthDs, _) = _recoveryAuth.stack;
    return DownloadDriveBackupUseCase(
      authRepository: _recoveryAuth,
      driveRemoteRepository: GoogleDriveBackupRemoteRepositoryImpl(
        googleAuthDs: googleAuthDs,
      ),
      restoreBackupUseCase: RestoreBackupUseCase(
        BackupRepositoryImpl(
          backupLocalDs: BackupLocalDs.fileOnly(
            documentsDirectoryResolver: getApplicationDocumentsDirectory,
          ),
        ),
        StorageService(),
      ),
    );
  }
}
