import 'package:daftar/application/backup/enqueue_drive_backup_upload_use_case.dart';
import 'package:daftar/application/backup/upload_drive_backup_use_case.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/services/storage_service.dart';
import 'package:daftar/domain/entities/app_settings.dart';
import 'package:daftar/domain/entities/backup_metadata.dart';
import 'package:daftar/domain/entities/encrypted_local_backup_snapshot.dart';
import 'package:daftar/domain/entities/google_drive_upload_result.dart';
import 'package:daftar/domain/enums/backup_type.dart';
import 'package:daftar/domain/repositories/auth_repository.dart';
import 'package:daftar/domain/repositories/backup_repository.dart';
import 'package:daftar/domain/repositories/google_drive_backup_remote_repository.dart';
import 'package:daftar/domain/repositories/settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockSettingsRepository extends Mock implements SettingsRepository {}

class MockBackupRepository extends Mock implements BackupRepository {}

class MockDriveRemoteRepository extends Mock
    implements GoogleDriveBackupRemoteRepository {}

class MockStorageService extends Mock implements StorageService {}

class MockEnqueueDriveBackupUploadUseCase extends Mock
    implements EnqueueDriveBackupUploadUseCase {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockAuthRepository authRepository;
  late MockSettingsRepository settingsRepository;
  late MockBackupRepository backupRepository;
  late MockDriveRemoteRepository driveRemoteRepository;
  late MockStorageService storageService;
  late MockEnqueueDriveBackupUploadUseCase enqueueUseCase;
  late UploadDriveBackupUseCase sut;

  final snapshot = EncryptedLocalBackupSnapshot(
    filePath: '/tmp/backup.daftar',
    sizeBytes: 128,
    checksum: 'checksum',
    createdAtUtc: DateTime.utc(2026, 6),
  );

  setUpAll(() {
    registerFallbackValue(const UpdateSettingsParams());
    registerFallbackValue(
      const GoogleDriveUploadResult(fileId: 'drive-file-1'),
    );
    registerFallbackValue(
      EncryptedLocalBackupSnapshot(
        filePath: '/fallback.daftar',
        sizeBytes: 1,
        checksum: 'x',
        createdAtUtc: DateTime.utc(2026),
      ),
    );
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    authRepository = MockAuthRepository();
    settingsRepository = MockSettingsRepository();
    backupRepository = MockBackupRepository();
    driveRemoteRepository = MockDriveRemoteRepository();
    storageService = MockStorageService();
    enqueueUseCase = MockEnqueueDriveBackupUploadUseCase();
    sut = UploadDriveBackupUseCase(
      authRepository: authRepository,
      settingsRepository: settingsRepository,
      backupRepository: backupRepository,
      driveRemoteRepository: driveRemoteRepository,
      storageService: storageService,
      enqueueDriveBackupUploadUseCase: enqueueUseCase,
    );
  });

  group('UploadDriveBackupUseCase', () {
    test('returns AuthFailure when silent sign-in fails', () async {
      when(() => authRepository.signInSilently()).thenAnswer(
        (_) async => const Left(AuthFailure.notSignedIn),
      );

      final result = await sut();

      expect(
        result,
        const Left<Failure, BackupMetadata>(AuthFailure.notSignedIn),
      );
      verifyNever(() => storageService.hasEnoughSpace());
    });

    test('returns StorageFullFailure when device storage is low', () async {
      when(() => authRepository.signInSilently()).thenAnswer(
        (_) async => const Right(unit),
      );
      when(() => storageService.hasEnoughSpace()).thenAnswer(
        (_) async => false,
      );

      final result = await sut();

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure, isA<StorageFullFailure>()),
        (_) => fail('expected failure'),
      );
    });

    test('returns backup repository failure when snapshot creation fails', () async {
      when(() => authRepository.signInSilently()).thenAnswer(
        (_) async => const Right(unit),
      );
      when(() => storageService.hasEnoughSpace()).thenAnswer(
        (_) async => true,
      );
      when(() => backupRepository.createEncryptedBackupFileOnly()).thenAnswer(
        (_) async => const Left(StorageFailure('encrypt failed')),
      );

      final result = await sut();

      expect(result.isLeft(), isTrue);
    });

    test('enqueues upload and returns NetworkFailure on transient upload error', () async {
      when(() => authRepository.signInSilently()).thenAnswer(
        (_) async => const Right(unit),
      );
      when(() => storageService.hasEnoughSpace()).thenAnswer(
        (_) async => true,
      );
      when(() => backupRepository.createEncryptedBackupFileOnly()).thenAnswer(
        (_) async => Right(snapshot),
      );
      when(() => settingsRepository.get()).thenAnswer(
        (_) async => const Right(AppSettings()),
      );
      when(
        () => driveRemoteRepository.uploadEncryptedBackup(
          absoluteFilePath: any(named: 'absoluteFilePath'),
          metadata: any(named: 'metadata'),
        ),
      ).thenAnswer(
        (_) async => const Left(NetworkFailure('offline')),
      );
      when(
        () => enqueueUseCase.call(
          encryptedBackupPath: any(named: 'encryptedBackupPath'),
          backupMetadataId: any(named: 'backupMetadataId'),
        ),
      ).thenAnswer((_) async {});

      final result = await sut();

      expect(result.isLeft(), isTrue);
      verify(
        () => enqueueUseCase.call(encryptedBackupPath: snapshot.filePath),
      ).called(1);
    });

    test('returns settings repository failure during upload', () async {
      when(() => authRepository.signInSilently()).thenAnswer(
        (_) async => const Right(unit),
      );
      when(() => storageService.hasEnoughSpace()).thenAnswer(
        (_) async => true,
      );
      when(() => backupRepository.createEncryptedBackupFileOnly()).thenAnswer(
        (_) async => Right(snapshot),
      );
      when(() => settingsRepository.get()).thenAnswer(
        (_) async => const Left(DatabaseFailure('settings read failed')),
      );

      final result = await sut();

      expect(result.isLeft(), isTrue);
    });

    test('returns success metadata after upload and insert', () async {
      final metadata = BackupMetadata(
        id: 'meta-1',
        filePath: snapshot.filePath,
        sizeBytes: snapshot.sizeBytes,
        checksum: snapshot.checksum,
        type: BackupType.cloud,
        createdAt: DateTime.utc(2026, 6),
        googleDriveFileId: 'drive-file-1',
      );
      when(() => authRepository.signInSilently()).thenAnswer(
        (_) async => const Right(unit),
      );
      when(() => storageService.hasEnoughSpace()).thenAnswer(
        (_) async => true,
      );
      when(() => backupRepository.createEncryptedBackupFileOnly()).thenAnswer(
        (_) async => Right(snapshot),
      );
      when(() => settingsRepository.get()).thenAnswer(
        (_) async => const Right(AppSettings()),
      );
      when(
        () => driveRemoteRepository.uploadEncryptedBackup(
          absoluteFilePath: any(named: 'absoluteFilePath'),
          metadata: any(named: 'metadata'),
        ),
      ).thenAnswer(
        (_) async => const Right(GoogleDriveUploadResult(fileId: 'drive-file-1')),
      );
      when(
        () => backupRepository.insertGoogleDriveBackupRecord(
          snapshot: any(named: 'snapshot'),
          googleDriveFileId: any(named: 'googleDriveFileId'),
        ),
      ).thenAnswer((_) async => Right(metadata));
      when(() => settingsRepository.update(any())).thenAnswer(
        (_) async => const Right(AppSettings()),
      );
      when(
        () => driveRemoteRepository.pruneOldRemoteBackups(
          keepNewest: any(named: 'keepNewest'),
        ),
      ).thenAnswer((_) async => const Right(unit));

      final result = await sut();

      expect(result, Right<Failure, BackupMetadata>(metadata));
      verify(
        () => driveRemoteRepository.pruneOldRemoteBackups(
          keepNewest: any(named: 'keepNewest'),
        ),
      ).called(1);
    });

    test('resumeFromEncryptedFilePath returns failure when snapshot build fails', () async {
      when(() => authRepository.signInSilently()).thenAnswer(
        (_) async => const Right(unit),
      );
      when(() => storageService.hasEnoughSpace()).thenAnswer(
        (_) async => true,
      );
      when(
        () => backupRepository.buildSnapshotFromEncryptedBackupFile(
          '/tmp/backup.daftar',
        ),
      ).thenAnswer(
        (_) async => const Left(ValidationFailure('corrupt backup')),
      );

      final result = await sut.resumeFromEncryptedFilePath('/tmp/backup.daftar');

      expect(result.isLeft(), isTrue);
    });
  });
}
