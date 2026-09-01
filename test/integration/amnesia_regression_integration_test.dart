import 'package:daftar/core/constants/db_constants.dart';
import 'package:daftar/core/env/env.dart';
import 'package:daftar/domain/enums/auth_session_state.dart';
import 'package:daftar/domain/enums/ledger_type.dart';
import 'package:daftar/domain/enums/transaction_type.dart';
import 'package:daftar/domain/repositories/settings_repository.dart';
import 'package:daftar/domain/services/auth_silent_sign_in_gateway.dart';
import 'package:daftar/presentation/providers/auth_providers.dart';
import 'package:daftar/presentation/providers/core_providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mocktail/mocktail.dart';

import '../application/backup/support/amnesia_test_harness.dart';
import '../application/backup/support/drive_backup_seed.dart';

class MockGoogleSignInAccount extends Mock implements GoogleSignInAccount {}

class MockAuthSilentSignInGateway extends Mock
    implements AuthSilentSignInGateway {}

const merchantId = 'google-sub-amnesia';
const merchantEmail = 'merchant@example.com';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(MockGoogleSignInAccount());
    registerFallbackValue(
      sampleAmnesiaBundle(),
    );
    registerFallbackValue(const UpdateSettingsParams());
  });

  late AmnesiaRegressionHarness harness;
  late MockGoogleSignInAccount merchantAccount;

  setUp(() async {
    merchantAccount = MockGoogleSignInAccount();
    when(() => merchantAccount.id).thenReturn(merchantId);
    when(() => merchantAccount.email).thenReturn(merchantEmail);
    when(() => merchantAccount.displayName).thenReturn('Merchant');

    harness = await AmnesiaRegressionHarness.create();
    await harness.bootForegroundContainer();
  });

  tearDown(() async {
    await harness.disposeHarness();
  });

  group('Phase 7.3 — Amnesia bug regression', () {
    test(
      'cold start bootstrap resolves to linked after process kill',
      () async {
        expect(Env.backupAesKey, isNotEmpty);

        await harness.signInWithAccount(merchantAccount);

        expect(await harness.authRepository.isSignedIn(), isTrue);
        expect(
          await harness.authRepository.getSessionState(),
          AuthSessionState.linked,
        );

        await harness.simulateProcessKill();
        await harness.bootColdStartContainer();

        when(() => harness.googleAuthDs.signInSilently()).thenAnswer(
          (_) async => merchantAccount,
        );
        when(() => harness.googleAuthDs.getAccount()).thenReturn(merchantAccount);

        expect(
          await harness.authRepository.getSessionState(),
          AuthSessionState.linked,
        );
        expect(await harness.authRepository.isSignedIn(), isTrue);

        final settingsRow = await harness.database
            .select(harness.database.appSettingsTable)
            .getSingle();
        expect(settingsRow.googleAccountId, merchantId);
        expect(settingsRow.googleAccountEmail, merchantEmail);
      },
    );

    test(
      'Drift ghost googleAccountId without bundle yields migrationRelinkRequired',
      () async {
        await harness.settingsRepository.update(
          const UpdateSettingsParams(
            googleAccountId: 'ghost-from-v1',
            googleAccountEmail: 'ghost@example.com',
          ),
        );

        await harness.simulateProcessKill();
        await harness.bootColdStartContainer();

        expect(
          await harness.authRepository.getSessionState(),
          AuthSessionState.migrationRelinkRequired,
        );
        expect(await harness.authRepository.isSignedIn(), isFalse);
        verifyNever(() => harness.googleAuthDs.signInSilently());
      },
    );

    test(
      'needsReauth does not block ledger mutations when silent auth fails',
      () async {
        final silentGateway = MockAuthSilentSignInGateway();
        when(() => silentGateway.attemptSilentRecovery(any())).thenAnswer(
          (_) async => false,
        );

        await harness.simulateProcessKill();
        await harness.bootColdStartContainer(
          silentSignInGateway: silentGateway,
        );

        final expiredBundle = sampleAmnesiaBundle().copyWith(
          cachedAccessToken: 'dead-token',
          cachedAccessTokenObtainedAt: DateTime.utc(2020),
          cachedAccessTokenExpiresAt: DateTime.utc(2020, 1, 2),
          driveRefreshToken: 'offline-refresh-token',
          driveTokenClientId: 'android-client.apps.googleusercontent.com',
        );
        await harness.writeBundleToVault(expiredBundle);

        when(() => harness.googleAuthDs.getAccount()).thenReturn(merchantAccount);
        when(() => harness.googleAuthDs.signInSilently()).thenAnswer(
          (_) async => null,
        );

        expect(
          await harness.authRepository.getSessionState(),
          AuthSessionState.needsReauth,
        );
        expect(await harness.authRepository.isSignedIn(), isTrue);

        when(() => harness.googleAuthDs.getAccount()).thenReturn(merchantAccount);

        final profile = await harness.container.read(googleAccountProvider.future);
        expect(profile, isNotNull);
        expect(profile?.id, merchantId);

        final ledger = await expectRight(
          harness.container
              .read(createLedgerUseCaseProvider)
              .execute(
                name: 'Amnesia Ledger',
                type: LedgerType.custom,
                icon: 'ledger',
                color: 0xFF1565C0,
              ),
        );

        final contact = await expectRight(
          harness.container
              .read(createContactUseCaseProvider)
              .execute(
                ledgerId: ledger.id,
                name: 'Amnesia Contact',
                phone: '+967700000099',
                notes: 'regression',
                creditLimit: 5000,
                creditCurrency: DbConstants.currencyYer,
                avatarColor: '#FF9800',
              ),
        );

        await expectRight(
          harness.container
              .read(addTransactionUseCaseProvider)
              .execute(
                contactId: contact.id,
                type: TransactionType.debt,
                amount: 750,
                currency: DbConstants.currencyYer,
                description: 'Seed',
                itemName: 'Item',
                transactionDate: DateTime.utc(2026, 6, 10),
              ),
        );
      },
    );
  });
}
