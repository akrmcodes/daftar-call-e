import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/data/datasources/remote/google_auth_ds.dart';
import 'package:daftar/data/datasources/remote/google_auth_exceptions.dart';
import 'package:daftar/data/datasources/remote/google_drive_backup_exceptions.dart';
import 'package:daftar/data/repositories/google_drive_backup_remote_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockGoogleAuthDs extends Mock implements GoogleAuthDs {}

void main() {
  late MockGoogleAuthDs googleAuthDs;
  late GoogleDriveBackupRemoteRepositoryImpl repository;

  setUp(() {
    googleAuthDs = MockGoogleAuthDs();
    repository = GoogleDriveBackupRemoteRepositoryImpl(
      googleAuthDs: googleAuthDs,
    );
  });

  group('GoogleDriveBackupRemoteRepositoryImpl', () {
    test('maps not signed in to AuthFailure', () async {
      when(() => googleAuthDs.getAuthenticatedHttpClient()).thenThrow(
        const GoogleAuthNotSignedInException(),
      );

      final result = await repository.listRemoteBackups();

      final failure = result.getLeft().toNullable();
      expect(failure, isA<AuthFailure>());
      expect(failure?.code, 'google_not_signed_in');
    });

    test('maps storage quota exceeded to QuotaExceededFailure', () async {
      when(() => googleAuthDs.getAuthenticatedHttpClient()).thenThrow(
        GoogleDriveBackupException(
          'Storage quota exceeded',
          status: 403,
          reason: 'storageQuotaExceeded',
        ),
      );

      final result = await repository.listRemoteBackups();

      final failure = result.getLeft().toNullable();
      expect(failure, isA<QuotaExceededFailure>());
      expect(failure?.code, 'drive_storage_quota_exceeded');
    });

    test('rejects empty file id on delete', () async {
      final result = await repository.deleteRemoteBackup('   ');

      final failure = result.getLeft().toNullable();
      expect(failure, isA<ValidationFailure>());
      expect(failure?.code, 'drive_empty_file_id');
      verifyNever(() => googleAuthDs.getAuthenticatedHttpClient());
    });

    test('maps Drive 401 to AuthFailure — never NetworkFailure', () async {
      when(() => googleAuthDs.getAuthenticatedHttpClient()).thenThrow(
        GoogleDriveBackupException(
          'Invalid Credentials',
          status: 401,
          reason: 'authError',
        ),
      );

      final result = await repository.listRemoteBackups();

      final failure = result.getLeft().toNullable();
      expect(failure, isA<AuthFailure>());
      expect(failure?.code, 'drive_unauthorized');
    });

    test('maps non-quota Drive 403 to AuthFailure', () async {
      when(() => googleAuthDs.getAuthenticatedHttpClient()).thenThrow(
        GoogleDriveBackupException(
          'The user does not have sufficient permissions',
          status: 403,
          reason: 'insufficientPermissions',
        ),
      );

      final result = await repository.listRemoteBackups();

      final failure = result.getLeft().toNullable();
      expect(failure, isA<AuthFailure>());
      expect(failure?.code, 'drive_forbidden');
    });

    test('keeps Drive 403 rate limits transient', () async {
      when(() => googleAuthDs.getAuthenticatedHttpClient()).thenThrow(
        GoogleDriveBackupException(
          'User rate limit exceeded',
          status: 403,
          reason: 'userRateLimitExceeded',
        ),
      );

      final result = await repository.listRemoteBackups();

      final failure = result.getLeft().toNullable();
      expect(failure, isA<NetworkFailure>());
      expect(failure?.code, 'drive_transient_403');
    });

    test('maps revoked offline grant to the dedicated reauth failure',
        () async {
      when(() => googleAuthDs.getAuthenticatedHttpClient()).thenThrow(
        const GoogleDriveGrantRevokedException(),
      );

      final result = await repository.listRemoteBackups();

      final failure = result.getLeft().toNullable();
      expect(failure, isA<AuthFailure>());
      expect(failure?.code, 'drive_refresh_token_revoked');
    });
  });
}
