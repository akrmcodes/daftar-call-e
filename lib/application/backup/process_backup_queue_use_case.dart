import 'package:daftar/application/backup/backup_queue_process_report.dart';
import 'package:daftar/application/backup/ensure_drive_session.dart';
import 'package:daftar/application/backup/upload_drive_backup_use_case.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/utils/backup_retry_policy.dart';
import 'package:daftar/domain/entities/backup_queue_item.dart';
import 'package:daftar/domain/enums/backup_queue_status.dart';
import 'package:daftar/domain/repositories/auth_repository.dart';
import 'package:daftar/domain/repositories/backup_queue_repository.dart';
import 'package:fpdart/fpdart.dart';

/// Processes persisted Drive backup queue rows after lifecycle or connectivity.
class ProcessBackupQueueUseCase {
  /// Creates a processor with injected collaborators.
  const ProcessBackupQueueUseCase({
    required AuthRepository authRepository,
    required BackupQueueRepository backupQueueRepository,
    required UploadDriveBackupUseCase uploadDriveBackupUseCase,
  })  : _authRepository = authRepository,
        _backupQueueRepository = backupQueueRepository,
        _uploadDriveBackupUseCase = uploadDriveBackupUseCase;

  final AuthRepository _authRepository;
  final BackupQueueRepository _backupQueueRepository;
  final UploadDriveBackupUseCase _uploadDriveBackupUseCase;

  /// Attempts each eligible pending upload once and updates queue rows.
  Future<BackupQueueProcessReport> call() async {
    var sawNeedsReauth = false;
    var sawQuotaExceeded = false;
    var sawTransientNetworkFailure = false;

    final items = await _backupQueueRepository.getPendingRetryable();
    for (final item in items) {
      final path = item.pendingBackupFilePath;
      if (path == null || path.trim().isEmpty) {
        continue;
      }

      final preflight = await _preflightSilentAuth();
      switch (preflight) {
        case Left(value: final failure):
          if (failure is AuthFailure && _isHardAuthFailure(failure)) {
            await _persistNeedsReauth(item);
            sawNeedsReauth = true;
            continue;
          }
          if (failure is AuthFailure) {
            await _persistTransientPreflightFailure(item);
            continue;
          }
          if (failure is NetworkFailure) {
            sawTransientNetworkFailure = true;
          }
          await _persistTransientPreflightFailure(item);
          continue;
        case Right():
          break;
      }

      await _backupQueueRepository.updateItem(
        item.copyWith(
          status: BackupQueueStatus.retrying,
          lastBackupAttemptAt: DateTime.now().toUtc(),
        ),
      );

      final result =
          await _uploadDriveBackupUseCase.resumeFromEncryptedFilePath(path);

      switch (result) {
        case Left(value: final failure):
          if (failure is AuthFailure && _isHardAuthFailure(failure)) {
            await _persistNeedsReauth(item);
            sawNeedsReauth = true;
            continue;
          }
          if (failure is AuthFailure) {
            await _persistTransientPreflightFailure(item);
            continue;
          }
          if (failure is QuotaExceededFailure) {
            await _backupQueueRepository.updateItem(
              item.copyWith(
                status: BackupQueueStatus.failed,
                lastBackupAttemptAt: DateTime.now().toUtc(),
                nextRetryAt: null,
              ),
            );
            sawQuotaExceeded = true;
            continue;
          }
          if (failure is NetworkFailure) {
            sawTransientNetworkFailure = true;
          }
          final newCount = item.backupRetryCount + 1;
          final terminal = newCount >= BackupRetryPolicy.maxAttempts;
          await _backupQueueRepository.updateItem(
            item.copyWith(
              status: terminal
                  ? BackupQueueStatus.failed
                  : BackupQueueStatus.queued,
              backupRetryCount: newCount,
              lastBackupAttemptAt: DateTime.now().toUtc(),
              nextRetryAt: terminal
                  ? null
                  : DateTime.now().toUtc().add(
                      BackupRetryPolicy.backoffDelayForFailureAttempt(newCount),
                    ),
            ),
          );
        case Right():
          await _backupQueueRepository.deleteItem(item.id);
      }
    }

    return BackupQueueProcessReport(
      sawNeedsReauth: sawNeedsReauth,
      sawQuotaExceeded: sawQuotaExceeded,
      sawTransientNetworkFailure: sawTransientNetworkFailure,
    );
  }

  /// Silent refresh before any snapshot read or Drive I/O for this queue item.
  Future<Either<Failure, Unit>> _preflightSilentAuth() {
    return ensureDriveSession(_authRepository);
  }

  bool _isHardAuthFailure(AuthFailure failure) {
    return isStickyNeedsReauthFailure(failure);
  }

  Future<void> _persistNeedsReauth(BackupQueueItem item) async {
    await _backupQueueRepository.updateItem(
      item.copyWith(
        status: BackupQueueStatus.needsReauth,
        lastBackupAttemptAt: DateTime.now().toUtc(),
        backupRetryCount: item.backupRetryCount + 1,
      ),
    );
  }

  Future<void> _persistTransientPreflightFailure(BackupQueueItem item) async {
    final newCount = item.backupRetryCount + 1;
    final terminal = newCount >= BackupRetryPolicy.maxAttempts;
    await _backupQueueRepository.updateItem(
      item.copyWith(
        status: terminal ? BackupQueueStatus.failed : BackupQueueStatus.queued,
        backupRetryCount: newCount,
        lastBackupAttemptAt: DateTime.now().toUtc(),
        nextRetryAt: terminal
            ? null
            : DateTime.now().toUtc().add(
                BackupRetryPolicy.backoffDelayForFailureAttempt(newCount),
              ),
      ),
    );
  }
}
