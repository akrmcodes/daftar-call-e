import 'package:daftar/core/env/env.dart';
import 'package:daftar/core/utils/uuid_util.dart';
import 'package:daftar/data/datasources/local/backup_queue_local_ds.dart';
import 'package:daftar/data/mappers/backup_metadata_mapper.dart';
import 'package:daftar/domain/constants/auth_scopes.dart';
import 'package:daftar/domain/entities/backup_queue_item.dart';
import 'package:daftar/domain/enums/backup_queue_status.dart';
import 'package:daftar/domain/enums/backup_type.dart';
import 'package:daftar/domain/enums/ledger_type.dart';
import 'package:daftar/domain/enums/transaction_type.dart';
import 'package:daftar/domain/repositories/settings_repository.dart';
import 'package:daftar/domain/value_objects/auth_session_bundle.dart';
import 'package:daftar/presentation/providers/backup_providers.dart';
import 'package:daftar/presentation/providers/core_providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mocktail/mocktail.dart';

import '../application/backup/support/auth_v2_test_wiring.dart';
import '../application/backup/support/drive_backup_seed.dart';

class MockGoogleSignInAccount extends Mock implements GoogleSignInAccount {}

const accountAId = 'google_account_a';
const accountAEmail = 'account.a@gmail.com';
const accountBId = 'google_account_b';
const accountBEmail = 'account.b@gmail.com';
const driveFileIdA = 'file_A_123';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(MockGoogleSignInAccount());
  });

  late Map<String, String> vault;
  late MockGoogleSignInAccount accountA;
  late MockGoogleSignInAccount accountB;
  var signInCallCount = 0;
  GoogleSignInAccount? activeAccount;

  setUp(() {
    vault = <String, String>{};
    signInCallCount = 0;
    activeAccount = null;

    accountA = MockGoogleSignInAccount();
    accountB = MockGoogleSignInAccount();

    when(() => accountA.id).thenReturn(accountAId);
    when(() => accountA.email).thenReturn(accountAEmail);
    when(() => accountA.displayName).thenReturn('Account A');
    when(() => accountB.id).thenReturn(accountBId);
    when(() => accountB.email).thenReturn(accountBEmail);
    when(() => accountB.displayName).thenReturn('Account B');
  });

  group('Phase 7.2 — Identity drift prevention', () {
    test(
      'sign out then sign in with a different account orphans Drive ids, '
      'purges the queue, logs SIGNED_OUT, and routes new uploads to B',
      () async {
        expect(Env.backupAesKey, isNotEmpty);

        final harness = await createIdentityDriftHarness(secureVault: vault);
        addTearDown(harness.dispose);

        when(harness.googleAuthDs.signOut).thenAnswer((_) async {
          activeAccount = null;
        });
        when(harness.googleAuthDs.signIn).thenAnswer((_) async {
          signInCallCount += 1;
          return activeAccount =
              signInCallCount == 1 ? accountA : accountB;
        });
        when(harness.googleAuthDs.signInSilently).thenAnswer(
          (_) async => activeAccount,
        );
        when(harness.googleAuthDs.getAccount).thenAnswer(
          (_) => activeAccount,
        );
        when(harness.googleAuthDs.isSignedIn).thenAnswer(
          (_) => activeAccount != null,
        );

        final authRepository = harness.authRepository;
        final backupQueueLocalDs = BackupQueueLocalDs(harness.database);

        await expectRight(authRepository.signInWithGoogle());
        expect(signInCallCount, 1);

        final backupId = UuidUtil.generate();
        await harness.database.into(harness.database.backupMetadatas).insert(
              buildBackupCompanion(
                id: backupId,
                filePath: '${harness.documentsDirectory.path}/account_a.daftar',
                sizeBytes: 128,
                createdAt: DateTime.utc(2026, 6, 4, 12),
                type: BackupType.googleDrive,
                checksum: 'checksum_account_a',
                googleDriveFileId: driveFileIdA,
              ),
            );

        await backupQueueLocalDs.insertItem(
          BackupQueueItem(
            id: UuidUtil.generate(),
            status: BackupQueueStatus.queued,
            backupMetadataId: backupId,
            pendingBackupFilePath:
                '${harness.documentsDirectory.path}/pending_account_a.daftar',
          ),
        );

        final seededBackup = await (harness.database
              .select(harness.database.backupMetadatas)
            ..where((t) => t.id.equals(backupId)))
            .getSingle();
        expect(seededBackup.googleDriveFileId, driveFileIdA);
        expect(
          await harness.database.select(harness.database.driveBackupQueueRows).get(),
          hasLength(1),
        );

        await expectRight(authRepository.signOut());

        final afterSignOutSettings =
            await harness.database.select(harness.database.appSettingsTable).getSingle();
        expect(afterSignOutSettings.googleAccountId, isNull);
        expect(afterSignOutSettings.googleAccountEmail, isNull);

        final afterSignOutBackup = await (harness.database
              .select(harness.database.backupMetadatas)
            ..where((t) => t.id.equals(backupId)))
            .getSingle();
        expect(afterSignOutBackup.googleDriveFileId, isNull);
        expect(
          await harness.database.select(harness.database.driveBackupQueueRows).get(),
          isEmpty,
        );

        final signedOutAudit = await harness.database
            .select(harness.database.auditLogs)
            .get();
        expect(
          signedOutAudit.any((row) => row.action == 'SIGNED_OUT'),
          isTrue,
        );
        expect(
          signedOutAudit.any((row) => row.action == 'ACCOUNT_SWITCH'),
          isFalse,
          reason: 'Sign-out path purges at sign-out — no ACCOUNT_SWITCH audit',
        );

        await expectRight(authRepository.signInWithGoogle());
        expect(signInCallCount, 2);
        expect(activeAccount?.id, accountBId);

        final persistedBackup = await (harness.database
              .select(harness.database.backupMetadatas)
            ..where((t) => t.id.equals(backupId)))
            .getSingle();
        expect(persistedBackup.googleDriveFileId, isNull);

        final queueRows =
            await harness.database.select(harness.database.driveBackupQueueRows).get();
        expect(queueRows, isEmpty);

        final settingsRow =
            await harness.database.select(harness.database.appSettingsTable).getSingle();
        expect(settingsRow.googleAccountId, accountBId);
        expect(settingsRow.googleAccountEmail, accountBEmail);

        await seedLedgerGraph(harness.container);

        final uploadResult = await expectRight(
          harness.container.read(uploadDriveBackupUseCaseProvider).call(),
        );
        expect(uploadResult.type, BackupType.googleDrive);
        expect(uploadResult.googleDriveFileId, isNotNull);
        expect(uploadResult.googleDriveFileId, isNot(driveFileIdA));
        expect(harness.remoteRepository.uploadCalls, 1);
        expect(harness.remoteRepository.lastUploadedFileId, isNotNull);

        await expectVaultBundleUserId(
          vault: vault,
          googleUserId: accountBId,
        );
      },
    );

    test(
      'direct account switch without sign-out runs ACCOUNT_SWITCH ceremony '
      'and attributes new uploads to B',
      () async {
        expect(Env.backupAesKey, isNotEmpty);

        final harness = await createIdentityDriftHarness(secureVault: vault);
        addTearDown(harness.dispose);

        when(harness.googleAuthDs.signOut).thenAnswer((_) async {
          activeAccount = null;
        });
        when(harness.googleAuthDs.signIn).thenAnswer((_) async {
          activeAccount = accountB;
          return accountB;
        });
        when(harness.googleAuthDs.signInSilently).thenAnswer(
          (_) async => activeAccount,
        );
        when(harness.googleAuthDs.getAccount).thenAnswer(
          (_) => activeAccount,
        );
        when(harness.googleAuthDs.isSignedIn).thenAnswer(
          (_) => activeAccount != null,
        );

        final bundleA = AuthSessionBundle.create(
          googleUserId: accountAId,
          email: accountAEmail,
          serverClientId: 'test-server-client.apps.googleusercontent.com',
          scopesGranted: AuthScopes.defaultDriveBackupScopes,
          linkedAt: DateTime.utc(2026, 6, 4, 10),
        );
        await persistBundleInVault(
          store: harness.authSessionStore,
          bundle: bundleA,
        );

        final settingsRepository = harness.container.read(settingsRepositoryProvider);
        await settingsRepository.update(
          const UpdateSettingsParams(
            googleAccountId: accountAId,
            googleAccountEmail: accountAEmail,
          ),
        );

        final backupId = UuidUtil.generate();
        await harness.database.into(harness.database.backupMetadatas).insert(
              buildBackupCompanion(
                id: backupId,
                filePath: '${harness.documentsDirectory.path}/account_a.daftar',
                sizeBytes: 128,
                createdAt: DateTime.utc(2026, 6, 4, 12),
                type: BackupType.googleDrive,
                checksum: 'checksum_account_a',
                googleDriveFileId: driveFileIdA,
              ),
            );

        final backupQueueLocalDs = BackupQueueLocalDs(harness.database);
        await backupQueueLocalDs.insertItem(
          BackupQueueItem(
            id: UuidUtil.generate(),
            status: BackupQueueStatus.queued,
            backupMetadataId: backupId,
            pendingBackupFilePath:
                '${harness.documentsDirectory.path}/pending_account_a.daftar',
          ),
        );

        await expectRight(harness.authRepository.signInWithGoogle());

        final afterSwitchBackup = await (harness.database
              .select(harness.database.backupMetadatas)
            ..where((t) => t.id.equals(backupId)))
            .getSingle();
        expect(afterSwitchBackup.googleDriveFileId, isNull);
        expect(
          await harness.database.select(harness.database.driveBackupQueueRows).get(),
          isEmpty,
        );

        final auditRows = await harness.database.select(harness.database.auditLogs).get();
        expect(
          auditRows.any(
            (row) =>
                row.action == 'ACCOUNT_SWITCH' &&
                row.entityType == 'google_account' &&
                row.entityId == accountBId &&
                (row.payload?.contains(accountAEmail) ?? false) &&
                (row.payload?.contains(accountBEmail) ?? false),
          ),
          isTrue,
          reason: 'ACCOUNT_SWITCH provenance must reference both accounts',
        );

        final settingsRow =
            await harness.database.select(harness.database.appSettingsTable).getSingle();
        expect(settingsRow.googleAccountId, accountBId);
        expect(settingsRow.googleAccountEmail, accountBEmail);

        await expectVaultBundleUserId(
          vault: vault,
          googleUserId: accountBId,
        );

        await expectRight(
          harness.container
              .read(createLedgerUseCaseProvider)
              .execute(
                name: 'Switch Ledger',
                type: LedgerType.custom,
                icon: 'ledger',
                color: 0xFF1565C0,
              ),
        );
        await expectRight(
          harness.container
              .read(createContactUseCaseProvider)
              .execute(
                ledgerId: (await harness.database.select(harness.database.ledgers).get())
                    .single
                    .id,
                name: 'Switch Contact',
                phone: '+967700000002',
                notes: 'integration',
                creditLimit: 5000,
                creditCurrency: 'YER',
                avatarColor: '#FF9800',
              ),
        );
        await expectRight(
          harness.container
              .read(addTransactionUseCaseProvider)
              .execute(
                contactId: (await harness.database
                        .select(harness.database.contacts)
                        .get())
                    .single
                    .id,
                type: TransactionType.debt,
                amount: 500,
                currency: 'YER',
                description: 'Seed',
                itemName: 'Item',
                transactionDate: DateTime.utc(2026, 6, 4),
              ),
        );

        final uploadResult = await expectRight(
          harness.container.read(uploadDriveBackupUseCaseProvider).call(),
        );
        expect(uploadResult.googleDriveFileId, isNot(driveFileIdA));
        expect(harness.remoteRepository.uploadCalls, 1);
      },
    );
  });
}
