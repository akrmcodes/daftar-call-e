import 'package:daftar/application/backup/ensure_drive_session.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/repositories/auth_repository.dart';
import 'package:daftar/domain/repositories/google_drive_backup_remote_repository.dart';
import 'package:fpdart/fpdart.dart';

/// Deletes a remote `.daftar` backup from Google Drive `appDataFolder`.
class DeleteDriveBackupUseCase {
  /// Creates a delete orchestrator.
  const DeleteDriveBackupUseCase({
    required AuthRepository authRepository,
    required GoogleDriveBackupRemoteRepository driveRemoteRepository,
  })  : _authRepository = authRepository,
        _driveRemoteRepository = driveRemoteRepository;

  final AuthRepository _authRepository;
  final GoogleDriveBackupRemoteRepository _driveRemoteRepository;

  /// Silent re-auth then permanently deletes [fileId] on Drive.
  Future<Either<Failure, Unit>> call(String fileId) async {
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

    return _driveRemoteRepository.deleteRemoteBackup(fileId);
  }
}
