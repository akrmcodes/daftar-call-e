import 'dart:io';

import 'package:daftar/application/backup/backup_queue_process_report.dart';
import 'package:daftar/application/backup/delete_drive_backup_use_case.dart';
import 'package:daftar/application/backup/download_drive_backup_use_case.dart';
import 'package:daftar/application/backup/enqueue_drive_backup_upload_use_case.dart';
import 'package:daftar/application/backup/restore_backup_use_case.dart';
import 'package:daftar/application/backup/upload_drive_backup_use_case.dart';
import 'package:daftar/core/constants/app_constants.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/services/connectivity_service.dart';
import 'package:daftar/core/services/storage_service.dart';
import 'package:daftar/domain/entities/app_settings.dart';
import 'package:daftar/domain/entities/backup_metadata.dart';
import 'package:daftar/domain/entities/encrypted_local_backup_snapshot.dart';
import 'package:daftar/domain/entities/google_drive_remote_backup_item.dart';
import 'package:daftar/domain/entities/google_drive_upload_result.dart';
import 'package:daftar/domain/enums/auth_session_state.dart';
import 'package:daftar/domain/enums/backup_type.dart';
import 'package:daftar/domain/repositories/auth_repository.dart';
import 'package:daftar/domain/repositories/backup_queue_repository.dart';
import 'package:daftar/domain/repositories/backup_repository.dart';
import 'package:daftar/domain/repositories/google_drive_backup_remote_repository.dart';
import 'package:daftar/domain/repositories/settings_repository.dart';
import 'package:daftar/presentation/providers/auth_providers.dart';
import 'package:daftar/presentation/providers/backup_providers.dart';
import 'package:daftar/presentation/providers/connectivity_providers.dart';
import 'package:daftar/presentation/providers/core_providers.dart';
import 'package:daftar/presentation/providers/storage_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockSettingsRepository extends Mock implements SettingsRepository {}

class MockBackupQueueRepository extends Mock implements BackupQueueRepository {}

class MockRestoreBackupUseCase extends Mock implements RestoreBackupUseCase {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    registerFallbackValue(const RestoreBackupParams(
      backupFilePath: '/tmp/x.daftar',
      expectedChecksum: 'checksum',
    ));
  });

  group('BackupNotifier', () {
    test('resets isRestoring after a successful restore', () async {
      final container = ProviderContainer(
        overrides: [
          backupRepositoryProvider.overrideWith(
            (ref) => const FakeBackupRepository(
              restoreResult: Right(unit),
            ),
          ),
          storageServiceProvider.overrideWith((ref) => _FakeStorageService()),
        ],
      );
      addTearDown(container.dispose);

      final subscription = container.listen(
        backupProvider,
        (previous, next) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      final notifier = container.read(backupProvider.notifier);

      final ok = await notifier.restoreBackup(
        File('/tmp/backup.daftar'),
        'checksum',
      );

      expect(ok, isTrue);
      expect(container.read(backupProvider).isRestoring, isFalse);
    });

    test('resets isRestoring after a failed restore', () async {
      final container = ProviderContainer(
        overrides: [
          backupRepositoryProvider.overrideWith(
            (ref) => const FakeBackupRepository(
              restoreResult: Left(
                StorageFailure('restore failed', code: 'restore_failed'),
              ),
            ),
          ),
          storageServiceProvider.overrideWith((ref) => _FakeStorageService()),
        ],
      );
      addTearDown(container.dispose);

      final subscription = container.listen(
        backupProvider,
        (previous, next) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      final notifier = container.read(backupProvider.notifier);

      final ok = await notifier.restoreBackup(
        File('/tmp/backup.daftar'),
        'checksum',
      );

      expect(ok, isFalse);
      expect(container.read(backupProvider).isRestoring, isFalse);
      expect(
        container.read(backupProvider).lastFailure,
        isA<StorageFailure>(),
      );
    });
  });

  group('DriveBackup', () {
    const remoteItem = GoogleDriveRemoteBackupItem(
      id: 'drive-file-1',
      name: 'backup.daftar',
      sizeBytes: 1024,
    );

    ProviderContainer driveContainer({
      required AuthSessionState session,
      Either<Failure, List<GoogleDriveRemoteBackupItem>>? listResult,
      Either<Failure, BackupMetadata>? uploadResult,
      Either<Failure, Unit>? deleteResult,
    }) {
      final authRepository = MockAuthRepository();
      when(authRepository.getSessionState).thenAnswer((_) async => session);
      when(authRepository.signInSilently)
          .thenAnswer((_) async => const Right(unit));

      final settingsRepository = MockSettingsRepository();
      when(settingsRepository.get)
          .thenAnswer((_) async => const Right(AppSettings()));

      final backupQueueRepository = MockBackupQueueRepository();
      when(backupQueueRepository.anyNeedsReauth)
          .thenAnswer((_) async => false);
      when(backupQueueRepository.getPendingRetryable)
          .thenAnswer((_) async => []);

      final remoteRepository = FakeGoogleDriveBackupRemoteRepository(
        listResult: listResult ?? const Right([remoteItem]),
        deleteResult: deleteResult ?? const Right(unit),
      );

      final restoreUseCase = MockRestoreBackupUseCase();

      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(authRepository),
          settingsRepositoryProvider.overrideWithValue(settingsRepository),
          backupQueueRepositoryProvider.overrideWithValue(backupQueueRepository),
          connectivityServiceProvider.overrideWith(
            (ref) => _FakeConnectivityService(),
          ),
          downloadDriveBackupUseCaseProvider.overrideWith(
            (ref) => DownloadDriveBackupUseCase(
              authRepository: authRepository,
              driveRemoteRepository: remoteRepository,
              restoreBackupUseCase: restoreUseCase,
            ),
          ),
          if (uploadResult != null)
            uploadDriveBackupUseCaseProvider.overrideWith(
              (ref) => _StubUploadDriveBackupUseCase(result: uploadResult),
            ),
          deleteDriveBackupUseCaseProvider.overrideWith(
            (ref) => DeleteDriveBackupUseCase(
              authRepository: authRepository,
              driveRemoteRepository: remoteRepository,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('refreshRemoteList resets state when session is unlinked', () async {
      final remoteRepository = FakeGoogleDriveBackupRemoteRepository(
        listResult: const Right([remoteItem]),
      );
      final authRepository = MockAuthRepository();
      when(authRepository.getSessionState)
          .thenAnswer((_) async => AuthSessionState.unlinked);

      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(authRepository),
          settingsRepositoryProvider.overrideWithValue(_emptySettingsRepo()),
          backupQueueRepositoryProvider.overrideWithValue(_emptyQueueRepo()),
          connectivityServiceProvider.overrideWith(
            (ref) => _FakeConnectivityService(),
          ),
          downloadDriveBackupUseCaseProvider.overrideWith(
            (ref) => DownloadDriveBackupUseCase(
              authRepository: authRepository,
              driveRemoteRepository: remoteRepository,
              restoreBackupUseCase: MockRestoreBackupUseCase(),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final subscription = container.listen(
        driveBackupProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      await container.read(driveBackupProvider.notifier).refreshRemoteList();

      expect(container.read(driveBackupProvider), const DriveBackupState());
      expect(remoteRepository.listCalls, 0);
    });

    Future<void> primeDriveProviders(ProviderContainer container) async {
      final syncSub = container.listen(
        backupSyncStatusProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(syncSub.close);
      for (var i = 0; i < 8; i++) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    test('refreshRemoteList populates remote backups when linked', () async {
      final container = driveContainer(session: AuthSessionState.linked);
      final subscription = container.listen(
        driveBackupProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      await primeDriveProviders(container);

      await container.read(driveBackupProvider.notifier).refreshRemoteList();

      final state = container.read(driveBackupProvider);
      expect(state.remoteBackups, [remoteItem]);
      expect(state.isLoadingList, isFalse);
      expect(
        container.read(backupSyncStatusProvider).surface,
        BackupSyncSurfaceState.synced,
      );
    });

    test('refreshRemoteList maps NetworkFailure to retry hint', () async {
      final container = driveContainer(
        session: AuthSessionState.linked,
        listResult: const Left(
          NetworkFailure('offline', code: 'network_error'),
        ),
      );
      final subscription = container.listen(
        driveBackupProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      await primeDriveProviders(container);

      await container.read(driveBackupProvider.notifier).refreshRemoteList();

      expect(
        container.read(driveBackupProvider).lastFailure,
        isA<NetworkFailure>(),
      );
      expect(
        container.read(backupSyncStatusProvider).driveRetryScheduled,
        isTrue,
      );
    });

    test('uploadToDrive records hard auth failure on drive state', () async {
      final container = driveContainer(
        session: AuthSessionState.linked,
        uploadResult: const Left(
          AuthFailure('not signed in', code: 'google_not_signed_in'),
        ),
      );
      final subscription = container.listen(
        driveBackupProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      await primeDriveProviders(container);

      final ok =
          await container.read(driveBackupProvider.notifier).uploadToDrive();

      expect(ok, isFalse);
      final failure = container.read(driveBackupProvider).lastFailure;
      expect(failure, isA<AuthFailure>());
      expect((failure! as AuthFailure).code, 'google_not_signed_in');
    });

    test('deleteRemote removes item from provider state', () async {
      final container = driveContainer(session: AuthSessionState.linked);
      final subscription = container.listen(
        driveBackupProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      await container.read(driveBackupProvider.notifier).refreshRemoteList();
      final ok = await container
          .read(driveBackupProvider.notifier)
          .deleteRemote('drive-file-1');

      expect(ok, isTrue);
      expect(container.read(driveBackupProvider).remoteBackups, isEmpty);
    });
  });

  group('BackupSyncStatus', () {
    Future<void> waitForBackupSyncBootstrap(ProviderContainer container) async {
      try {
        await container.read(authStateProvider.future);
      } on Object {
        // Auth may be overridden without a FutureProvider completion path.
      }
      for (var i = 0; i < 8; i++) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    ProviderContainer syncContainer({
      ConnectivityStatus connectivity = ConnectivityStatus.online,
    }) {
      final authRepository = MockAuthRepository();
      when(authRepository.getSessionState)
          .thenAnswer((_) async => AuthSessionState.linked);

      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(authRepository),
          settingsRepositoryProvider.overrideWithValue(_emptySettingsRepo()),
          backupQueueRepositoryProvider.overrideWithValue(_emptyQueueRepo()),
          connectivityServiceProvider.overrideWith(
            (ref) => _FakeConnectivityService(status: connectivity),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('offline surface beats needsReauth hint', () async {
      final container = syncContainer(connectivity: ConnectivityStatus.offline);
      final subscription = container.listen(
        backupSyncStatusProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      await waitForBackupSyncBootstrap(container);
      container.read(backupSyncStatusProvider.notifier).applyQueueProcessReport(
            const BackupQueueProcessReport(sawNeedsReauth: true),
          );

      expect(
        container.read(backupSyncStatusProvider).surface,
        BackupSyncSurfaceState.offline,
      );
    });

    test('transient network report sets syncing surface and retry hint', () async {
      final container = syncContainer();
      final subscription = container.listen(
        backupSyncStatusProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      await waitForBackupSyncBootstrap(container);
      container.read(backupSyncStatusProvider.notifier).applyQueueProcessReport(
            const BackupQueueProcessReport(
              sawTransientNetworkFailure: true,
            ),
          );

      final view = container.read(backupSyncStatusProvider);
      expect(view.surface, BackupSyncSurfaceState.syncing);
      expect(view.driveRetryScheduled, isTrue);
    });

    test('quota exceeded report sets quota surface when online', () async {
      final container = syncContainer();
      final subscription = container.listen(
        backupSyncStatusProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      await waitForBackupSyncBootstrap(container);
      container.read(backupSyncStatusProvider.notifier).applyQueueProcessReport(
            const BackupQueueProcessReport(sawQuotaExceeded: true),
          );

      expect(
        container.read(backupSyncStatusProvider).surface,
        BackupSyncSurfaceState.quotaExceeded,
      );
    });

    test('needsReauth surface when session is needsReauth', () async {
      final authRepository = MockAuthRepository();
      when(authRepository.getSessionState)
          .thenAnswer((_) async => AuthSessionState.needsReauth);

      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(authRepository),
          settingsRepositoryProvider.overrideWithValue(_emptySettingsRepo()),
          backupQueueRepositoryProvider.overrideWithValue(_emptyQueueRepo()),
          connectivityServiceProvider.overrideWith(
            (ref) => _FakeConnectivityService(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final subscription = container.listen(
        backupSyncStatusProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      await waitForBackupSyncBootstrap(container);

      expect(
        container.read(backupSyncStatusProvider).surface,
        BackupSyncSurfaceState.needsReauth,
      );
    });

    test('clearDriveRetryScheduledHint clears retry flag', () async {
      final container = syncContainer();
      final subscription = container.listen(
        backupSyncStatusProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      await waitForBackupSyncBootstrap(container);
      container.read(backupSyncStatusProvider.notifier)
        ..applyQueueProcessReport(
          const BackupQueueProcessReport(sawTransientNetworkFailure: true),
        )
        ..clearDriveRetryScheduledHint();

      expect(
        container.read(backupSyncStatusProvider).driveRetryScheduled,
        isFalse,
      );
    });
  });
}

MockSettingsRepository _emptySettingsRepo() {
  final repo = MockSettingsRepository();
  when(repo.get).thenAnswer((_) async => const Right(AppSettings()));
  return repo;
}

MockBackupQueueRepository _emptyQueueRepo() {
  final repo = MockBackupQueueRepository();
  when(repo.anyNeedsReauth).thenAnswer((_) async => false);
  when(repo.getPendingRetryable).thenAnswer((_) async => []);
  return repo;
}

class FakeBackupRepository implements BackupRepository {
  const FakeBackupRepository({
    required this.restoreResult,
    this.listResult = const Right(<BackupMetadata>[]),
  });

  final Either<Failure, Unit> restoreResult;
  final Either<Failure, List<BackupMetadata>> listResult;

  @override
  Future<Either<Failure, BackupMetadata>> createLocal() async {
    return const Left(DatabaseFailure('createLocal is not used in this test'));
  }

  @override
  Future<Either<Failure, EncryptedLocalBackupSnapshot>>
      createEncryptedBackupFileOnly() async {
    return const Left(
      StorageFailure('createEncryptedBackupFileOnly is not used in this test'),
    );
  }

  @override
  Future<Either<Failure, BackupMetadata>> insertGoogleDriveBackupRecord({
    required EncryptedLocalBackupSnapshot snapshot,
    required String googleDriveFileId,
  }) async {
    return const Left(
      DatabaseFailure('insertGoogleDriveBackupRecord is not used in this test'),
    );
  }

  @override
  Future<Either<Failure, EncryptedLocalBackupSnapshot>>
      buildSnapshotFromEncryptedBackupFile(String absolutePath) async {
    return const Left(
      StorageFailure(
        'buildSnapshotFromEncryptedBackupFile is not used in this test',
      ),
    );
  }

  @override
  Future<Either<Failure, Unit>> deleteBackup(String id) async {
    return const Left(DatabaseFailure('deleteBackup is not used in this test'));
  }

  @override
  Future<Either<Failure, Unit>> downloadCloud(String backupId) async {
    return const Left(NetworkFailure('downloadCloud is not used in this test'));
  }

  @override
  Future<Either<Failure, List<BackupMetadata>>> listBackups({
    BackupType? filterType,
  }) async {
    return listResult;
  }

  @override
  Future<Either<Failure, Unit>> restoreLocal(
    String filePath, {
    required String expectedChecksum,
  }) async {
    return restoreResult;
  }

  @override
  Future<Either<Failure, BackupMetadata>> uploadCloud() async {
    return const Left(NetworkFailure('uploadCloud is not used in this test'));
  }
}

/// Skips platform disk-space probes so provider tests stay hermetic.
class _FakeStorageService extends StorageService {
  @override
  Future<bool> hasEnoughSpace({
    int minMegabytes = AppConstants.minFreeStorageMegabytes,
  }) async {
    return true;
  }
}

class _FakeConnectivityService extends ConnectivityService {
  _FakeConnectivityService({this.status = ConnectivityStatus.online});

  final ConnectivityStatus status;

  @override
  Future<ConnectivityStatus> currentStatus() async => status;

  @override
  Stream<ConnectivityStatus> watchStatus() async* {
    yield status;
  }
}

class FakeGoogleDriveBackupRemoteRepository
    implements GoogleDriveBackupRemoteRepository {
  FakeGoogleDriveBackupRemoteRepository({
    required this.listResult,
    this.deleteResult = const Right(unit),
  });

  final Either<Failure, List<GoogleDriveRemoteBackupItem>> listResult;
  final Either<Failure, Unit> deleteResult;
  int listCalls = 0;

  @override
  Future<Either<Failure, Unit>> deleteIfPresent(String absolutePath) async {
    return const Left(NetworkFailure('not used'));
  }

  @override
  Future<Either<Failure, Unit>> deleteRemoteBackup(String fileId) async {
    return deleteResult;
  }

  @override
  Future<Either<Failure, String>> downloadBackupToTemporaryFile(
    String fileId,
  ) async {
    return const Left(NetworkFailure('not used'));
  }

  @override
  Future<Either<Failure, Unit>> downloadBackupToFile({
    required String fileId,
    required String destinationPath,
  }) async {
    return const Left(NetworkFailure('not used'));
  }

  @override
  Future<Either<Failure, GoogleDriveRemoteBackupItem>> fetchRemoteBackupById(
    String fileId,
  ) async {
    return const Left(NetworkFailure('not used'));
  }

  @override
  Future<Either<Failure, List<GoogleDriveRemoteBackupItem>>>
      listRemoteBackups() async {
    listCalls++;
    return listResult;
  }

  @override
  Future<Either<Failure, GoogleDriveUploadResult>> uploadEncryptedBackup({
    required String absoluteFilePath,
    required Map<String, String> metadata,
  }) async {
    return const Left(NetworkFailure('not used'));
  }

  @override
  Future<Either<Failure, Unit>> pruneOldRemoteBackups({
    required int keepNewest,
  }) async {
    return const Right(unit);
  }
}

class _StubUploadDriveBackupUseCase extends UploadDriveBackupUseCase {
  _StubUploadDriveBackupUseCase({required this.result})
      : super(
          authRepository: _UnreachableAuthRepository(),
          settingsRepository: _UnreachableSettingsRepository(),
          backupRepository: const FakeBackupRepository(
            restoreResult: Right(unit),
          ),
          driveRemoteRepository: _UnreachableDriveRemoteRepository(),
          storageService: _FakeStorageService(),
          enqueueDriveBackupUploadUseCase: EnqueueDriveBackupUploadUseCase(
            _UnreachableBackupQueueRepository(),
          ),
        );

  final Either<Failure, BackupMetadata> result;

  @override
  Future<Either<Failure, BackupMetadata>> call() async => result;
}

class _UnreachableAuthRepository extends Mock implements AuthRepository {}

class _UnreachableSettingsRepository extends Mock
    implements SettingsRepository {}

class _UnreachableDriveRemoteRepository extends Mock
    implements GoogleDriveBackupRemoteRepository {}

class _UnreachableBackupQueueRepository extends Mock
    implements BackupQueueRepository {}
