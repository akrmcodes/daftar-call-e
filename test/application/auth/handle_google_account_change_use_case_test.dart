import 'dart:async';

import 'package:daftar/application/auth/handle_google_account_change_use_case.dart';
import 'package:daftar/core/constants/app_constants.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/services/auth_session_store.dart';
import 'package:daftar/data/datasources/local/audit_log_local_ds.dart';
import 'package:daftar/data/datasources/local/backup_local_ds.dart';
import 'package:daftar/data/datasources/local/backup_queue_local_ds.dart';
import 'package:daftar/data/datasources/local/drift_database.dart';
import 'package:daftar/data/repositories/google_identity_repository_impl.dart';
import 'package:daftar/domain/constants/auth_scopes.dart';
import 'package:daftar/domain/entities/backup_queue_item.dart';
import 'package:daftar/domain/enums/backup_queue_status.dart';
import 'package:daftar/domain/enums/backup_type.dart';
import 'package:daftar/domain/repositories/google_identity_repository.dart';
import 'package:daftar/domain/value_objects/auth_session_bundle.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockGoogleIdentityRepository extends Mock
    implements GoogleIdentityRepository {}

class MockAuthSessionStore extends Mock implements AuthSessionStore {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockGoogleIdentityRepository googleIdentityRepository;
  late MockAuthSessionStore authSessionStore;
  late List<String> callOrder;

  const params = HandleGoogleAccountChangeParams(
    oldEmail: 'old@example.com',
    newEmail: 'new@example.com',
    newAccountId: 'google-new',
  );

  setUp(() {
    googleIdentityRepository = MockGoogleIdentityRepository();
    authSessionStore = MockAuthSessionStore();
    callOrder = [];

    when(() => authSessionStore.delete()).thenAnswer((_) async {
      callOrder.add('delete');
    });
    when(
      () => googleIdentityRepository.purgeDriveIdentityOnAccountSwitch(
        oldEmail: any(named: 'oldEmail'),
        newEmail: any(named: 'newEmail'),
        newAccountId: any(named: 'newAccountId'),
      ),
    ).thenAnswer((_) async {
      callOrder.add('purge');
      return const Right(unit);
    });
  });

  HandleGoogleAccountChangeUseCase buildUseCase({
    Future<void> Function()? cancelBackgroundSync,
  }) {
    return HandleGoogleAccountChangeUseCase(
      googleIdentityRepository,
      authSessionStore,
      cancelBackgroundSync: cancelBackgroundSync ??
          () async {
            callOrder.add('cancel');
          },
    );
  }

  group('HandleGoogleAccountChangeUseCase', () {
    test('runs cancel → purge → delete in order', () async {
      final useCase = buildUseCase();

      final result = await useCase(params);

      expect(await expectRight(result), unit);
      expect(callOrder, ['cancel', 'purge', 'delete']);
      verify(() => authSessionStore.delete()).called(1);
      verify(
        () => googleIdentityRepository.purgeDriveIdentityOnAccountSwitch(
          oldEmail: 'old@example.com',
          newEmail: 'new@example.com',
          newAccountId: 'google-new',
        ),
      ).called(1);
    });

    test('returns Left when purge fails and never deletes session', () async {
      when(
        () => googleIdentityRepository.purgeDriveIdentityOnAccountSwitch(
          oldEmail: any(named: 'oldEmail'),
          newEmail: any(named: 'newEmail'),
          newAccountId: any(named: 'newAccountId'),
        ),
      ).thenAnswer((_) async {
        callOrder.add('purge');
        return const Left(DatabaseFailure('purge failed'));
      });

      final useCase = buildUseCase();
      final result = await useCase(params);

      expect(result.isLeft(), isTrue);
      expect(callOrder, ['cancel', 'purge']);
      verifyNever(() => authSessionStore.delete());
    });

    test('abort before purge and delete when cancel throws', () async {
      final useCase = buildUseCase(
        cancelBackgroundSync: () async {
          callOrder.add('cancel');
          throw StateError('cancel failed');
        },
      );

      await expectLater(useCase(params), throwsA(isA<StateError>()));
      expect(callOrder, ['cancel']);
      verifyNever(() => authSessionStore.delete());
      verifyNever(
        () => googleIdentityRepository.purgeDriveIdentityOnAccountSwitch(
          oldEmail: any(named: 'oldEmail'),
          newEmail: any(named: 'newEmail'),
          newAccountId: any(named: 'newAccountId'),
        ),
      );
    });

    test('propagates delete failure after successful purge', () async {
      when(() => authSessionStore.delete()).thenAnswer((_) async {
        callOrder.add('delete');
        throw StateError('delete failed');
      });

      final useCase = buildUseCase();

      await expectLater(useCase(params), throwsA(isA<StateError>()));
      expect(callOrder, ['cancel', 'purge', 'delete']);
    });
  });

  group('HandleGoogleAccountChangeUseCase integration', () {
    late Map<String, String> vault;
    late AuthSessionStore sessionStore;
    late AppDatabase database;
    late GoogleIdentityRepositoryImpl identityRepository;

    AuthSessionBundle sampleBundle() => AuthSessionBundle.create(
          googleUserId: 'google-sub-123',
          email: 'merchant@example.com',
          serverClientId: 'web-client-id.apps.googleusercontent.com',
          scopesGranted: AuthScopes.defaultDriveBackupScopes,
          linkedAt: DateTime.utc(2026, 6, 8, 12),
        );

    setUp(() {
      vault = <String, String>{};
      FlutterSecureStoragePlatform.instance =
          TestFlutterSecureStoragePlatform(vault);
      sessionStore = AuthSessionStore(storage: const FlutterSecureStorage());
      database = AppDatabase(NativeDatabase.memory());
      identityRepository = GoogleIdentityRepositoryImpl(
        database: database,
        backupLocalDs: BackupLocalDs(database),
        backupQueueLocalDs: BackupQueueLocalDs(database),
        auditLogLocalDataSource: AuditLogLocalDataSource(database),
      );
    });

    tearDown(() async {
      await database.close();
    });

    Future<void> seedDriftDriveState() async {
      await database.into(database.backupMetadatas).insert(
            BackupMetadatasCompanion.insert(
              id: 'backup-1',
              filePath: '/tmp/backup.daftar',
              sizeBytes: 1024,
              type: BackupType.googleDrive,
              checksum: 'abc',
              googleDriveFileId: const Value('drive-file-1'),
            ),
          );
      await BackupQueueLocalDs(database).insertItem(
        const BackupQueueItem(
          id: 'queue-1',
          status: BackupQueueStatus.queued,
          pendingBackupFilePath: '/tmp/pending.daftar',
        ),
      );
    }

    test('successful ceremony purges Drift and deletes secure bundle', () async {
      await sessionStore.write(sampleBundle());
      await seedDriftDriveState();

      final useCase = HandleGoogleAccountChangeUseCase(
        identityRepository,
        sessionStore,
        cancelBackgroundSync: () async {},
      );

      final result = await useCase(params);

      expect(await expectRight(result), unit);
      expect(await sessionStore.read(), isNull);
      expect(vault.containsKey(AppConstants.authSessionStorageKey), isFalse);

      final backupRow = await (database.select(database.backupMetadatas)
            ..where((t) => t.id.equals('backup-1')))
          .getSingle();
      expect(backupRow.googleDriveFileId, isNull);

      final queueRows = await database.select(database.driveBackupQueueRows).get();
      expect(queueRows, isEmpty);

      final auditRows = await database.select(database.auditLogs).get();
      expect(auditRows.single.action, 'ACCOUNT_SWITCH');
    });

    test('failed purge leaves secure bundle and Drift Drive state intact', () async {
      await sessionStore.write(sampleBundle());
      await seedDriftDriveState();

      final failingRepository = MockGoogleIdentityRepository();
      when(
        () => failingRepository.purgeDriveIdentityOnAccountSwitch(
          oldEmail: any(named: 'oldEmail'),
          newEmail: any(named: 'newEmail'),
          newAccountId: any(named: 'newAccountId'),
        ),
      ).thenAnswer(
        (_) async => const Left(DatabaseFailure('purge failed')),
      );

      final useCase = HandleGoogleAccountChangeUseCase(
        failingRepository,
        sessionStore,
        cancelBackgroundSync: () async {},
      );

      final result = await useCase(params);

      expect(result.isLeft(), isTrue);
      expect(await sessionStore.read(), sampleBundle());
      expect(vault.containsKey(AppConstants.authSessionStorageKey), isTrue);

      final backupRow = await (database.select(database.backupMetadatas)
            ..where((t) => t.id.equals('backup-1')))
          .getSingle();
      expect(backupRow.googleDriveFileId, 'drive-file-1');

      final queueRows = await database.select(database.driveBackupQueueRows).get();
      expect(queueRows, hasLength(1));
    });
  });
}

Future<T> expectRight<T>(FutureOr<Either<Failure, T>> resultOrFuture) async {
  final result = await resultOrFuture;
  return result.fold(
    (failure) => fail('Expected Right but got Left($failure)'),
    (value) => value,
  );
}
