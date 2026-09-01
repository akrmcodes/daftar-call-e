import 'package:daftar/application/backup/upload_drive_backup_use_case.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/utils/cloud_sync_failure.dart';
import 'package:daftar/domain/enums/closing_backup_status.dart';
import 'package:daftar/domain/services/drive_session_gateway.dart';
import 'package:fpdart/fpdart.dart';

/// Maps a Drive backup upload result to a close-the-day ritual status.
///
/// Grant gaps (`silent_sign_in_failed` when linked but Drive not granted) must
/// not be classified as offline queue — see close-day report copy.
ClosingBackupStatus mapClosingBackupStatus(Either<Failure, Object> result) {
  final failure = result.getLeft().toNullable();
  if (failure == null) {
    return ClosingBackupStatus.uploaded;
  }
  if (failure is AuthFailure && failure.code == 'google_not_signed_in') {
    return ClosingBackupStatus.skippedUnsigned;
  }
  if (_isGrantRequiredFailure(failure)) {
    return ClosingBackupStatus.grantRequired;
  }
  if (failure.code == kBackupInProgressFailureCode ||
      isTransientCloudSyncFailure(failure)) {
    return ClosingBackupStatus.queued;
  }
  return ClosingBackupStatus.failed;
}

bool _isGrantRequiredFailure(Failure failure) {
  if (failure is! AuthFailure) {
    return false;
  }
  return switch (failure.code) {
    'silent_sign_in_failed' ||
    kDriveScopesNotAuthorizedCode ||
    'drive_offline_grant_failed' => true,
    _ => false,
  };
}
