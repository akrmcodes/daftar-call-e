import 'package:daftar/application/backup/enqueue_drive_backup_upload_use_case.dart';
import 'package:daftar/application/backup/ensure_drive_session.dart';
import 'package:daftar/application/backup/process_backup_queue_use_case.dart';
import 'package:daftar/application/backup/upload_drive_backup_use_case.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/services/pending_cloud_sync_store.dart';
import 'package:daftar/domain/entities/backup_metadata.dart';
import 'package:daftar/domain/entities/backup_queue_item.dart';
import 'package:daftar/domain/enums/backup_queue_status.dart';
import 'package:daftar/domain/enums/backup_type.dart';
import 'package:daftar/domain/repositories/auth_repository.dart';
import 'package:daftar/domain/repositories/backup_queue_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockBackupQueueRepository extends Mock implements BackupQueueRepository {}

class MockUploadDriveBackupUseCase extends Mock
    implements UploadDriveBackupUseCase {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockAuthRepository authRepository;
  late MockBackupQueueRepository backupQueueRepository;
  late MockUploadDriveBackupUseCase uploadDriveBackupUseCase;

  setUpAll(() {
    registerFallbackValue(
      const BackupQueueItem(
        id: 'fallback-queue-id',
        status: BackupQueueStatus.queued,
      ),
    );
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    authRepository = MockAuthRepository();
    backupQueueRepository = MockBackupQueueRepository();
    uploadDriveBackupUseCase = MockUploadDriveBackupUseCase();
  });

  group('EnqueueDriveBackupUploadUseCase', () {
    test('returns early when encrypted path is empty', () async {
      final sut = EnqueueDriveBackupUploadUseCase(backupQueueRepository);
      when(() => backupQueueRepository.getPendingRetryable()).thenAnswer(
        (_) async => const [],
      );

      await sut.call(encryptedBackupPath: '   ');

      verifyNever(() => backupQueueRepository.insertItem(any()));
      expect(await PendingCloudSyncStore.hasPending(), isFalse);
    });

    test('inserts queue row and marks pending cloud sync', () async {
      final sut = EnqueueDriveBackupUploadUseCase(backupQueueRepository);
      when(() => backupQueueRepository.getPendingRetryable()).thenAnswer(
        (_) async => const [],
      );
      when(() => backupQueueRepository.insertItem(any())).thenAnswer((_) async {});

      await sut.call(encryptedBackupPath: '/tmp/backup.daftar');

      verify(() => backupQueueRepository.insertItem(any())).called(1);
      expect(await PendingCloudSyncStore.hasPending(), isTrue);
    });

    test('skips insert when matching pending path already exists', () async {
      final sut = EnqueueDriveBackupUploadUseCase(backupQueueRepository);
      when(() => backupQueueRepository.getPendingRetryable()).thenAnswer(
        (_) async => [
          const BackupQueueItem(
            id: 'queue-1',
            status: BackupQueueStatus.queued,
            pendingBackupFilePath: '/tmp/backup.daftar',
          ),
        ],
      );

      await sut.call(encryptedBackupPath: '/tmp/backup.daftar');

      verifyNever(() => backupQueueRepository.insertItem(any()));
      expect(await PendingCloudSyncStore.hasPending(), isTrue);
    });
  });

  group('ProcessBackupQueueUseCase', () {
    late ProcessBackupQueueUseCase sut;

    setUp(() {
      sut = ProcessBackupQueueUseCase(
        authRepository: authRepository,
        backupQueueRepository: backupQueueRepository,
        uploadDriveBackupUseCase: uploadDriveBackupUseCase,
      );
    });

    test('returns empty report when queue has no items', () async {
      when(() => backupQueueRepository.getPendingRetryable()).thenAnswer(
        (_) async => const [],
      );

      final report = await sut();

      expect(report.sawNeedsReauth, isFalse);
      expect(report.sawQuotaExceeded, isFalse);
      expect(report.sawTransientNetworkFailure, isFalse);
    });

    test('skips items with empty pending backup path', () async {
      when(() => backupQueueRepository.getPendingRetryable()).thenAnswer(
        (_) async => [
          const BackupQueueItem(
            id: 'queue-1',
            status: BackupQueueStatus.queued,
            pendingBackupFilePath: '  ',
          ),
        ],
      );

      final report = await sut();

      expect(report.sawNeedsReauth, isFalse);
      verifyNever(() => authRepository.signInSilently());
    });

    test('marks item needsReauth on hard auth preflight failure', () async {
      const item = BackupQueueItem(
        id: 'queue-1',
        status: BackupQueueStatus.queued,
        pendingBackupFilePath: '/tmp/backup.daftar',
      );
      when(() => backupQueueRepository.getPendingRetryable()).thenAnswer(
        (_) async => [item],
      );
      when(() => authRepository.signInSilently()).thenAnswer(
        (_) async => const Left(
          AuthFailure(
            'revoked',
            code: kDriveRefreshTokenRevokedFailureCode,
          ),
        ),
      );
      when(() => backupQueueRepository.updateItem(any())).thenAnswer(
        (_) async {},
      );

      final report = await sut();

      expect(report.sawNeedsReauth, isTrue);
      verify(
        () => backupQueueRepository.updateItem(
          any(
            that: predicate<BackupQueueItem>(
              (updated) => updated.status == BackupQueueStatus.needsReauth,
            ),
          ),
        ),
      ).called(1);
    });

    test('deletes queue item after successful upload resume', () async {
      const item = BackupQueueItem(
        id: 'queue-1',
        status: BackupQueueStatus.queued,
        pendingBackupFilePath: '/tmp/backup.daftar',
      );
      final metadata = BackupMetadata(
        id: 'meta-1',
        filePath: '/tmp/backup.daftar',
        sizeBytes: 100,
        checksum: 'abc',
        type: BackupType.cloud,
        createdAt: DateTime.utc(2026, 6),
      );
      when(() => backupQueueRepository.getPendingRetryable()).thenAnswer(
        (_) async => [item],
      );
      when(() => authRepository.signInSilently()).thenAnswer(
        (_) async => const Right(unit),
      );
      when(() => backupQueueRepository.updateItem(any())).thenAnswer(
        (_) async {},
      );
      when(
        () => uploadDriveBackupUseCase.resumeFromEncryptedFilePath(
          '/tmp/backup.daftar',
        ),
      ).thenAnswer((_) async => Right(metadata));
      when(() => backupQueueRepository.deleteItem('queue-1')).thenAnswer(
        (_) async {},
      );

      final report = await sut();

      expect(report.sawNeedsReauth, isFalse);
      verify(() => backupQueueRepository.deleteItem('queue-1')).called(1);
    });

    test('schedules retry on transient network upload failure', () async {
      const item = BackupQueueItem(
        id: 'queue-1',
        status: BackupQueueStatus.queued,
        pendingBackupFilePath: '/tmp/backup.daftar',
      );
      when(() => backupQueueRepository.getPendingRetryable()).thenAnswer(
        (_) async => [item],
      );
      when(() => authRepository.signInSilently()).thenAnswer(
        (_) async => const Right(unit),
      );
      when(() => backupQueueRepository.updateItem(any())).thenAnswer(
        (_) async {},
      );
      when(
        () => uploadDriveBackupUseCase.resumeFromEncryptedFilePath(
          '/tmp/backup.daftar',
        ),
      ).thenAnswer(
        (_) async => const Left(NetworkFailure('offline')),
      );

      final report = await sut();

      expect(report.sawTransientNetworkFailure, isTrue);
      verify(
        () => backupQueueRepository.updateItem(
          any(
            that: predicate<BackupQueueItem>(
              (updated) =>
                  updated.status == BackupQueueStatus.queued &&
                  updated.backupRetryCount == 1 &&
                  updated.nextRetryAt != null,
            ),
          ),
        ),
      ).called(greaterThanOrEqualTo(1));
    });

    test('marks item failed when upload hits quota exceeded', () async {
      const item = BackupQueueItem(
        id: 'queue-1',
        status: BackupQueueStatus.queued,
        pendingBackupFilePath: '/tmp/backup.daftar',
      );
      when(() => backupQueueRepository.getPendingRetryable()).thenAnswer(
        (_) async => [item],
      );
      when(() => authRepository.signInSilently()).thenAnswer(
        (_) async => const Right(unit),
      );
      when(() => backupQueueRepository.updateItem(any())).thenAnswer(
        (_) async {},
      );
      when(
        () => uploadDriveBackupUseCase.resumeFromEncryptedFilePath(
          '/tmp/backup.daftar',
        ),
      ).thenAnswer(
        (_) async => const Left(QuotaExceededFailure('quota')),
      );

      final report = await sut();

      expect(report.sawQuotaExceeded, isTrue);
      verify(
        () => backupQueueRepository.updateItem(
          any(
            that: predicate<BackupQueueItem>(
              (updated) => updated.status == BackupQueueStatus.failed,
            ),
          ),
        ),
      ).called(greaterThanOrEqualTo(1));
    });

    test('requeues item on soft auth failure during upload', () async {
      const item = BackupQueueItem(
        id: 'queue-1',
        status: BackupQueueStatus.queued,
        pendingBackupFilePath: '/tmp/backup.daftar',
      );
      when(() => backupQueueRepository.getPendingRetryable()).thenAnswer(
        (_) async => [item],
      );
      when(() => authRepository.signInSilently()).thenAnswer(
        (_) async => const Right(unit),
      );
      when(() => backupQueueRepository.updateItem(any())).thenAnswer(
        (_) async {},
      );
      when(
        () => uploadDriveBackupUseCase.resumeFromEncryptedFilePath(
          '/tmp/backup.daftar',
        ),
      ).thenAnswer(
        (_) async => const Left(AuthFailure('transient', code: 'network_error')),
      );

      final report = await sut();

      expect(report.sawNeedsReauth, isFalse);
      verify(
        () => backupQueueRepository.updateItem(
          any(
            that: predicate<BackupQueueItem>(
              (updated) => updated.status == BackupQueueStatus.queued,
            ),
          ),
        ),
      ).called(greaterThanOrEqualTo(1));
    });
  });
}
