// Test-only mocktail and provider scaffolding intentionally triggers these lints.
// ignore_for_file: prefer_const_constructors, avoid_redundant_argument_values, unnecessary_lambdas

import 'dart:convert';
import 'dart:io';

import 'package:daftar/application/backup/restore_backup_use_case.dart';
import 'package:daftar/application/backup/upload_drive_backup_use_case.dart';
import 'package:daftar/bootstrap.dart';
import 'package:daftar/core/env/env.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/utils/uuid_util.dart';
import 'package:daftar/data/datasources/local/drift_database.dart'
    hide BackupMetadata;
import 'package:daftar/domain/entities/app_settings.dart';
import 'package:daftar/domain/entities/backup_metadata.dart';
import 'package:daftar/domain/entities/backup_queue_item.dart';
import 'package:daftar/domain/entities/encrypted_local_backup_snapshot.dart';
import 'package:daftar/domain/entities/google_drive_remote_backup_item.dart';
import 'package:daftar/domain/entities/google_drive_upload_result.dart';
import 'package:daftar/domain/enums/backup_queue_status.dart';
import 'package:daftar/domain/enums/backup_type.dart';
import 'package:daftar/domain/repositories/settings_repository.dart';
import 'package:daftar/presentation/providers/backup_providers.dart';
import 'package:daftar/presentation/providers/core_providers.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';

import 'support/drive_backup_seed.dart';
import 'support/drive_backup_stubs.dart';
import 'support/drive_backup_test_harness.dart';
import 'support/fake_drive_backup_remote_repository.dart';

class MockRestoreBackupUseCase extends Mock implements RestoreBackupUseCase {}

class MockUploadDriveBackupUseCase extends Mock
    implements UploadDriveBackupUseCase {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(const AppSettings());
    registerFallbackValue(const UpdateSettingsParams());
    registerFallbackValue(
      const RestoreBackupParams(
        backupFilePath: '/tmp/fallback.daftar',
        expectedChecksum: 'fallback-checksum',
      ),
    );
    registerFallbackValue(
      BackupQueueItem(
        id: 'fallback-queue-id',
        status: BackupQueueStatus.queued,
      ),
    );
    registerFallbackValue(
      BackupMetadata(
        id: 'fallback-backup-id',
        filePath: '/tmp/fallback.daftar',
        sizeBytes: 1,
        createdAt: DateTime.utc(2026, 1, 1),
        type: BackupType.googleDrive,
        checksum: 'fallback-checksum',
      ),
    );
    registerFallbackValue(
      EncryptedLocalBackupSnapshot(
        filePath: '/tmp/fallback.daftar',
        sizeBytes: 1,
        checksum: 'fallback-checksum',
        createdAtUtc: DateTime.utc(2026, 1, 1),
      ),
    );
    registerFallbackValue(
      const GoogleDriveRemoteBackupItem(
        id: 'fallback-remote-id',
        name: 'fallback.daftar',
      ),
    );
    registerFallbackValue(
      const GoogleDriveUploadResult(fileId: 'fallback-upload-id'),
    );
  });

  group('Phase 7.2 — Drive backup integration', () {
    group('1. Happy path', () {
      test(
        'uploads, lists, downloads, and restores the original data',
        () async {
          expect(Env.backupAesKey, isNotEmpty);

          final authRepository = MockAuthRepository();
          final settingsRepository = MockSettingsRepository();
          final googleAuthDs = MockGoogleAuthDs();
          final remoteRepository = FakeDriveBackupRemoteRepository();

          stubSignedInAuth(authRepository);
          stubSettingsRepository(settingsRepository);
          stubGoogleAuthDs(googleAuthDs);

          final harness = await createDriveBackupHarness(
            authRepository: authRepository,
            settingsRepository: settingsRepository,
            googleAuthDs: googleAuthDs,
            remoteRepository: remoteRepository,
          );
          addTearDown(harness.dispose);

          final seed = await seedLedgerGraph(harness.container);

          final uploadResult = await expectRight(
            harness.container.read(uploadDriveBackupUseCaseProvider).call(),
          );
          expect(uploadResult.type, BackupType.googleDrive);
          expect(uploadResult.googleDriveFileId, isNotNull);
          expect(File(uploadResult.filePath).existsSync(), isTrue);
          expect(remoteRepository.uploadCalls, 1);

          final remoteBackups = await expectRight(
            harness.container
                .read(downloadDriveBackupUseCaseProvider)
                .listAvailableBackups(),
          );
          expect(remoteBackups, hasLength(1));
          expect(remoteBackups.single.id, uploadResult.googleDriveFileId);
          expect(
            remoteBackups.single.appProperties?['checksum'],
            uploadResult.checksum,
          );

          final mutatedLedger = await expectRight(
            harness.container
                .read(updateLedgerUseCaseProvider)
                .execute(
                  seed.ledger.copyWith(name: 'بعد النسخ الاحتياطي'),
                ),
          );
          expect(mutatedLedger.name, 'بعد النسخ الاحتياطي');

          final restoreResult = await expectRight(
            harness.container
                .read(downloadDriveBackupUseCaseProvider)
                .restoreBackup(uploadResult.googleDriveFileId!),
          );
          expect(restoreResult, unit);

          final restoredDatabase = await openDatabase(
            documentsDirectory: harness.documentsDirectory,
          );
          addTearDown(restoredDatabase.close);

          final restoredLedgers = await restoredDatabase
              .select(restoredDatabase.ledgers)
              .get();
          final restoredContacts = await restoredDatabase
              .select(restoredDatabase.contacts)
              .get();
          final restoredTransactions = await restoredDatabase
              .select(restoredDatabase.transactions)
              .get();

          expect(restoredLedgers, hasLength(1));
          expect(restoredLedgers.single.name, seed.ledger.name);
          expect(restoredContacts, hasLength(1));
          expect(restoredContacts.single.name, seed.contact.name);
          expect(restoredTransactions, hasLength(1));
          expect(restoredTransactions.single.amount, 1250);
          expect(restoredTransactions.single.itemName, 'Flour');

          verify(() => authRepository.signInSilently()).called(3);
          expect(remoteRepository.deletedTempPaths, hasLength(1));
          expect(
            File(remoteRepository.deletedTempPaths.single).existsSync(),
            isFalse,
          );
        },
      );
    });

    group('2. Token refresh', () {
      test('refreshes a stale session silently before upload', () async {
        expect(Env.backupAesKey, isNotEmpty);

        final authRepository = MockAuthRepository();
        final settingsRepository = MockSettingsRepository();
        final googleAuthDs = MockGoogleAuthDs();
        final remoteRepository = FakeDriveBackupRemoteRepository();

        stubSignedInAuth(authRepository);
        stubSettingsRepository(settingsRepository);
        stubGoogleAuthDs(googleAuthDs);

        var silentCalls = 0;
        when(() => authRepository.signInSilently()).thenAnswer((_) async {
          silentCalls += 1;
          if (silentCalls == 1) {
            return const Left(AuthFailure.notSignedIn);
          }
          return const Right(unit);
        });

        final harness = await createDriveBackupHarness(
          authRepository: authRepository,
          settingsRepository: settingsRepository,
          googleAuthDs: googleAuthDs,
          remoteRepository: remoteRepository,
        );
        addTearDown(harness.dispose);

        await seedLedgerGraph(harness.container);

        final uploadUseCase =
            harness.container.read(uploadDriveBackupUseCaseProvider);

        final firstAttempt = await expectLeft(uploadUseCase.call());
        expect(firstAttempt, isA<AuthFailure>());

        final uploadResult = await expectRight(uploadUseCase.call());

        expect(uploadResult.type, BackupType.googleDrive);
        expect(uploadResult.googleDriveFileId, isNotNull);
        expect(silentCalls, 2);
        expect(remoteRepository.uploadCalls, 1);
        expect(
          remoteRepository.lastUploadedMetadata?['checksum'],
          uploadResult.checksum,
        );
        verifyNever(() => authRepository.signInWithGoogle());
      });
    });

    group('3. Quota exhaustion', () {
      test(
        'maps a 403 storageQuotaExceeded response to a terminal failure '
        'without enqueueing a queue row',
        () async {
          expect(Env.backupAesKey, isNotEmpty);

          final authRepository = MockAuthRepository();
          final settingsRepository = MockSettingsRepository();
          final googleAuthDs = MockGoogleAuthDs();

          stubSignedInAuth(authRepository);
          stubSettingsRepository(settingsRepository);
          stubGoogleAuthDs(googleAuthDs);

          final quotaClient = MockClient((request) async {
            return http.Response(
              jsonEncode(
                {
                  'error': {
                    'code': 403,
                    'message': 'storageQuotaExceeded',
                    'errors': [
                      {
                        'message': 'storageQuotaExceeded',
                        'domain': 'usageLimits',
                        'reason': 'storageQuotaExceeded',
                      },
                    ],
                  },
                },
              ),
              403,
              headers: const {
                'content-type': 'application/json; charset=utf-8',
              },
            );
          });

          when(
            () => googleAuthDs.getAuthenticatedHttpClient(),
          ).thenAnswer((_) async => quotaClient);

          final harness = await createDriveBackupHarness(
            authRepository: authRepository,
            settingsRepository: settingsRepository,
            googleAuthDs: googleAuthDs,
          );
          addTearDown(harness.dispose);

          await seedLedgerGraph(harness.container);

          final failure = await expectLeft(
            harness.container.read(uploadDriveBackupUseCaseProvider).call(),
          );

          expect(failure, isA<QuotaExceededFailure>());
          expect(
            failure.message,
            'Your Google Drive is full. Free up space or delete old Daftar backups.',
          );
          expect(failure.code, 'drive_storage_quota_exceeded');

          final queueRows =
              await harness.database.select(harness.database.driveBackupQueueRows).get();
          expect(queueRows, isEmpty);

          verify(() => authRepository.signInSilently()).called(1);
          verify(() => googleAuthDs.getAuthenticatedHttpClient()).called(1);
        },
      );

      test(
        'marks queued quota failures as failed with no retry schedule '
        'and never re-invokes upload across 10 processor passes',
        () async {
          final authRepository = MockAuthRepository();
          final settingsRepository = MockSettingsRepository();
          final googleAuthDs = MockGoogleAuthDs();
          final uploadUseCase = MockUploadDriveBackupUseCase();

          stubSignedInAuth(authRepository);
          stubSettingsRepository(settingsRepository);
          stubGoogleAuthDs(googleAuthDs);

          final harness = await createDriveBackupHarness(
            authRepository: authRepository,
            settingsRepository: settingsRepository,
            googleAuthDs: googleAuthDs,
            uploadDriveBackupUseCase: uploadUseCase,
          );
          addTearDown(harness.dispose);

          final backup = await expectRight(
            harness.container.read(createLocalBackupUseCaseProvider).call(),
          );

          final queueId = UuidUtil.generate();
          final queueRepository =
              harness.container.read(backupQueueRepositoryProvider);
          await queueRepository.insertItem(
            BackupQueueItem(
              id: queueId,
              status: BackupQueueStatus.queued,
              pendingBackupFilePath: backup.filePath,
              backupRetryCount: 0,
            ),
          );

          when(
            () => uploadUseCase.resumeFromEncryptedFilePath(any()),
          ).thenAnswer(
            (_) async => const Left(
              QuotaExceededFailure(
                'Your Google Drive is full. Free up space or delete old Daftar backups.',
                code: 'drive_storage_quota_exceeded',
              ),
            ),
          );

          for (var pass = 0; pass < 10; pass++) {
            final report = await harness.container
                .read(processBackupQueueUseCaseProvider)
                .call();

            expect(report.sawQuotaExceeded, pass == 0);

            final row = await (harness.database
                  .select(harness.database.driveBackupQueueRows)
                ..where((t) => t.id.equals(queueId)))
                .getSingleOrNull();
            expect(row, isNotNull);
            expect(row!.status, 'failed');
            expect(row.nextRetryAt, isNull);
            expect(row.backupRetryCount, 0);
          }

          verify(
            () => uploadUseCase.resumeFromEncryptedFilePath(backup.filePath),
          ).called(1);
        },
      );
    });

    group('4. Network failure & retry', () {
      test(
        'schedules retry state and succeeds after eligibility is restored',
        () async {
          final authRepository = MockAuthRepository();
          final settingsRepository = MockSettingsRepository();
          final googleAuthDs = MockGoogleAuthDs();
          final uploadUseCase = MockUploadDriveBackupUseCase();

          stubSignedInAuth(authRepository);
          stubSettingsRepository(settingsRepository);
          stubGoogleAuthDs(googleAuthDs);

          final harness = await createDriveBackupHarness(
            authRepository: authRepository,
            settingsRepository: settingsRepository,
            googleAuthDs: googleAuthDs,
            uploadDriveBackupUseCase: uploadUseCase,
          );
          addTearDown(harness.dispose);

          final backup = await expectRight(
            harness.container.read(createLocalBackupUseCaseProvider).call(),
          );

          final queueId = UuidUtil.generate();
          final queueRepository =
              harness.container.read(backupQueueRepositoryProvider);
          await queueRepository.insertItem(
            BackupQueueItem(
              id: queueId,
              status: BackupQueueStatus.queued,
              pendingBackupFilePath: backup.filePath,
              backupRetryCount: 0,
            ),
          );

          var processingRound = 0;
          when(
            () => uploadUseCase.resumeFromEncryptedFilePath(any()),
          ).thenAnswer((_) async {
            processingRound += 1;
            if (processingRound == 1) {
              return const Left(
                NetworkFailure(
                  'Simulated socket failure',
                  code: 'drive_socket',
                ),
              );
            }
            return Right(
              BackupMetadata(
                id: 'queued-success-id',
                filePath: backup.filePath,
                sizeBytes: backup.sizeBytes,
                createdAt: backup.createdAt,
                type: BackupType.googleDrive,
                checksum: backup.checksum,
              ),
            );
          });

          final firstReport = await harness.container
              .read(processBackupQueueUseCaseProvider)
              .call();
          expect(firstReport.sawTransientNetworkFailure, isTrue);

          final afterFirstPass = await (harness.database
                .select(harness.database.driveBackupQueueRows)
              ..where((t) => t.id.equals(queueId)))
              .getSingle();
          expect(afterFirstPass.status, 'queued');
          expect(afterFirstPass.backupRetryCount, 1);
          expect(afterFirstPass.nextRetryAt, isNotNull);

          await (harness.database.update(harness.database.driveBackupQueueRows)
                ..where((t) => t.id.equals(queueId)))
              .write(
            DriveBackupQueueRowsCompanion(
              nextRetryAt: Value(DateTime.utc(2020, 1, 1)),
            ),
          );

          final secondReport = await harness.container
              .read(processBackupQueueUseCaseProvider)
              .call();
          expect(secondReport.sawTransientNetworkFailure, isFalse);

          final remainingRows =
              await harness.database.select(harness.database.driveBackupQueueRows).get();
          expect(remainingRows, isEmpty);

          verify(
            () => uploadUseCase.resumeFromEncryptedFilePath(backup.filePath),
          ).called(2);
        },
      );
    });

    group('5. Corrupted download', () {
      test(
        'rejects junk bytes, never reaches restore, and leaves DB unchanged',
        () async {
          final authRepository = MockAuthRepository();
          final settingsRepository = MockSettingsRepository();
          final googleAuthDs = MockGoogleAuthDs();
          final restoreBackupUseCase = MockRestoreBackupUseCase();
          final remoteRepository = FakeDriveBackupRemoteRepository();

          stubSignedInAuth(authRepository);
          stubSettingsRepository(settingsRepository);
          stubGoogleAuthDs(googleAuthDs);

          when(() => restoreBackupUseCase.call(any())).thenAnswer(
            (_) async => const Right(unit),
          );

          final harness = await createDriveBackupHarness(
            authRepository: authRepository,
            settingsRepository: settingsRepository,
            googleAuthDs: googleAuthDs,
            remoteRepository: remoteRepository,
            restoreBackupUseCase: restoreBackupUseCase,
          );
          addTearDown(harness.dispose);

          final seed = await seedLedgerGraph(harness.container);
          final ledgerCountBefore = await harness.database
              .select(harness.database.ledgers)
              .get()
              .then((rows) => rows.length);
          final contactNameBefore = seed.contact.name;
          final transactionAmountBefore = await harness.database
              .select(harness.database.transactions)
              .get()
              .then((rows) => rows.single.amount);

          const badFileId = 'corrupted-drive-file';
          remoteRepository.seedRemoteBackup(
            fileId: badFileId,
            bytes: Uint8List.fromList(List<int>.generate(22, (index) => index)),
            metadata: const {'checksum': 'deadbeef'},
            name: 'corrupted.daftar',
          );

          final failure = await expectLeft(
            harness.container
                .read(downloadDriveBackupUseCaseProvider)
                .restoreBackup(badFileId),
          );

          expect(failure, isA<ValidationFailure>());
          expect(
            failure.message,
            'Backup file is damaged. Please try another backup.',
          );

          verify(() => authRepository.signInSilently()).called(1);
          verifyNever(() => restoreBackupUseCase.call(any()));
          expect(remoteRepository.deletedTempPaths, hasLength(1));
          expect(
            File(remoteRepository.deletedTempPaths.single).existsSync(),
            isFalse,
          );

          final ledgerCountAfter = await harness.database
              .select(harness.database.ledgers)
              .get()
              .then((rows) => rows.length);
          final contactNameAfter = await harness.database
              .select(harness.database.contacts)
              .get()
              .then((rows) => rows.single.name);
          final transactionAmountAfter = await harness.database
              .select(harness.database.transactions)
              .get()
              .then((rows) => rows.single.amount);

          expect(ledgerCountAfter, ledgerCountBefore);
          expect(contactNameAfter, contactNameBefore);
          expect(transactionAmountAfter, transactionAmountBefore);
        },
      );
    });
  });
}
