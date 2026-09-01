import 'package:daftar/application/backup/download_drive_backup_use_case.dart';
import 'package:daftar/application/backup/restore_backup_use_case.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/entities/google_drive_remote_backup_item.dart';
import 'package:daftar/domain/repositories/auth_repository.dart';
import 'package:daftar/domain/repositories/google_drive_backup_remote_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockDriveRemoteRepository extends Mock
    implements GoogleDriveBackupRemoteRepository {}

class MockRestoreBackupUseCase extends Mock implements RestoreBackupUseCase {}

void main() {
  late MockAuthRepository authRepository;
  late MockDriveRemoteRepository driveRemoteRepository;
  late MockRestoreBackupUseCase restoreBackupUseCase;
  late DownloadDriveBackupUseCase sut;

  setUp(() {
    authRepository = MockAuthRepository();
    driveRemoteRepository = MockDriveRemoteRepository();
    restoreBackupUseCase = MockRestoreBackupUseCase();
    sut = DownloadDriveBackupUseCase(
      authRepository: authRepository,
      driveRemoteRepository: driveRemoteRepository,
      restoreBackupUseCase: restoreBackupUseCase,
    );
  });

  group('DownloadDriveBackupUseCase', () {
    test('listAvailableBackups returns auth failure', () async {
      when(() => authRepository.signInSilently()).thenAnswer(
        (_) async => const Left(AuthFailure.notSignedIn),
      );

      final result = await sut.listAvailableBackups();

      expect(
        result,
        const Left<Failure, List<GoogleDriveRemoteBackupItem>>(
          AuthFailure.notSignedIn,
        ),
      );
      verifyNever(() => driveRemoteRepository.listRemoteBackups());
    });

    test('listAvailableBackups delegates to remote repository', () async {
      const backups = [
        GoogleDriveRemoteBackupItem(
          id: 'file-1',
          name: 'backup.daftar',
          sizeBytes: 100,
        ),
      ];
      when(() => authRepository.signInSilently()).thenAnswer(
        (_) async => const Right(unit),
      );
      when(() => driveRemoteRepository.listRemoteBackups()).thenAnswer(
        (_) async => const Right(backups),
      );

      final result = await sut.listAvailableBackups();

      expect(
        result,
        const Right<Failure, List<GoogleDriveRemoteBackupItem>>(backups),
      );
    });

    test('restoreBackup returns ValidationFailure for empty file id', () async {
      final result = await sut.restoreBackup('  ');

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure.code, 'drive_empty_file_id'),
        (_) => fail('expected failure'),
      );
    });

    test('restoreBackup returns metadata failure before download', () async {
      when(() => authRepository.signInSilently()).thenAnswer(
        (_) async => const Right(unit),
      );
      when(() => driveRemoteRepository.fetchRemoteBackupById('file-1')).thenAnswer(
        (_) async => const Left(NetworkFailure('metadata failed')),
      );

      final result = await sut.restoreBackup('file-1');

      expect(result.isLeft(), isTrue);
      verifyNever(
        () => driveRemoteRepository.downloadBackupToTemporaryFile(any()),
      );
    });

    test('restoreBackup returns auth failure before metadata fetch', () async {
      when(() => authRepository.signInSilently()).thenAnswer(
        (_) async => const Left(AuthFailure.notSignedIn),
      );

      final result = await sut.restoreBackup('file-1');

      expect(
        result,
        const Left<Failure, Unit>(AuthFailure.notSignedIn),
      );
      verifyNever(() => driveRemoteRepository.fetchRemoteBackupById(any()));
    });
  });
}
