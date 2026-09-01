import 'package:daftar/application/agent/map_closing_backup_status.dart';
import 'package:daftar/application/backup/upload_drive_backup_use_case.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/enums/closing_backup_status.dart';
import 'package:daftar/domain/services/drive_session_gateway.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

void main() {
  test('success maps to uploaded', () {
    expect(
      mapClosingBackupStatus(const Right<Failure, Object>(Object())),
      ClosingBackupStatus.uploaded,
    );
  });

  test('google_not_signed_in maps to skippedUnsigned', () {
    expect(
      mapClosingBackupStatus(
        const Left(AuthFailure('not signed in', code: 'google_not_signed_in')),
      ),
      ClosingBackupStatus.skippedUnsigned,
    );
  });

  test('silent_sign_in_failed maps to grantRequired', () {
    expect(
      mapClosingBackupStatus(
        const Left(AuthFailure('silent', code: 'silent_sign_in_failed')),
      ),
      ClosingBackupStatus.grantRequired,
    );
  });

  test('drive_scopes_not_authorized maps to grantRequired', () {
    expect(
      mapClosingBackupStatus(
        const Left(
          AuthFailure('scopes', code: kDriveScopesNotAuthorizedCode),
        ),
      ),
      ClosingBackupStatus.grantRequired,
    );
  });

  test('network failure maps to queued', () {
    expect(
      mapClosingBackupStatus(const Left(NetworkFailure('offline'))),
      ClosingBackupStatus.queued,
    );
  });

  test('backup in progress maps to queued', () {
    expect(
      mapClosingBackupStatus(
        const Left(
          StorageFailure('busy', code: kBackupInProgressFailureCode),
        ),
      ),
      ClosingBackupStatus.queued,
    );
  });

  test('other failures map to failed', () {
    expect(
      mapClosingBackupStatus(
        const Left(StorageFailure('upload failed', code: 'backup_failed')),
      ),
      ClosingBackupStatus.failed,
    );
  });
}
