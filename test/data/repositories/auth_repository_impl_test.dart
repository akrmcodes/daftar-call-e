import 'dart:async';

import 'package:daftar/application/auth/handle_google_account_change_use_case.dart';
import 'package:daftar/application/auth/reconcile_drift_identity_use_case.dart';
import 'package:daftar/application/auth/session_bootstrap_coordinator.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/services/auth_session_store.dart';
import 'package:daftar/core/services/device_identity_store.dart';
import 'package:daftar/data/datasources/local/audit_log_local_ds.dart';
import 'package:daftar/data/datasources/local/backup_local_ds.dart';
import 'package:daftar/data/datasources/local/backup_queue_local_ds.dart';
import 'package:daftar/data/datasources/remote/drive_offline_grant_ds.dart';
import 'package:daftar/data/datasources/remote/google_auth_ds.dart';
import 'package:daftar/data/models/audit_log_model.dart';
import 'package:daftar/data/repositories/auth_repository_impl.dart';
import 'package:daftar/domain/constants/auth_scopes.dart';
import 'package:daftar/domain/entities/app_settings.dart';
import 'package:daftar/domain/entities/google_account_profile.dart';
import 'package:daftar/domain/enums/auth_session_state.dart';
import 'package:daftar/domain/repositories/auth_repository.dart';
import 'package:daftar/domain/repositories/settings_repository.dart';
import 'package:daftar/domain/value_objects/auth_session_bundle.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mocktail/mocktail.dart';

class MockGoogleAuthDs extends Mock implements GoogleAuthDs {}

class MockAuthSessionStore extends Mock implements AuthSessionStore {}

class MockSettingsRepository extends Mock implements SettingsRepository {}

class MockReconcileDriftIdentityUseCase extends Mock
    implements ReconcileDriftIdentityUseCase {}

class MockHandleGoogleAccountChangeUseCase extends Mock
    implements HandleGoogleAccountChangeUseCase {}

class MockSessionBootstrapCoordinator extends Mock
    implements SessionBootstrapCoordinator {}

class MockBackupLocalDs extends Mock implements BackupLocalDs {}

class MockBackupQueueLocalDs extends Mock implements BackupQueueLocalDs {}

class MockAuditLogLocalDataSource extends Mock
    implements AuditLogLocalDataSource {}

class MockGoogleSignInAccount extends Mock implements GoogleSignInAccount {}

class StubDriveOfflineGrantDs extends DriveOfflineGrantDs {
  StubDriveOfflineGrantDs({this.grant});

  final DriveOfflineGrant? grant;
  int acquireCalls = 0;

  @override
  Future<DriveOfflineGrant?> acquire({required String loginHint}) async {
    acquireCalls++;
    return grant ??
        (
          refreshToken: 'offline-refresh-token',
          clientId: 'android-client.apps.googleusercontent.com',
          accessToken: 'offline-access-token',
          accessTokenExpiresAt: DateTime.utc(2026, 7),
          idToken: null,
        );
  }
}

void main() {
  late MockGoogleAuthDs googleAuthDs;
  late MockAuthSessionStore authSessionStore;
  late MockSettingsRepository settingsRepository;
  late MockReconcileDriftIdentityUseCase reconcileUseCase;
  late MockHandleGoogleAccountChangeUseCase handleAccountChangeUseCase;
  late MockSessionBootstrapCoordinator sessionBootstrapCoordinator;
  late MockBackupLocalDs backupLocalDs;
  late MockBackupQueueLocalDs backupQueueLocalDs;
  late MockAuditLogLocalDataSource auditLogLocalDataSource;
  late StubDriveOfflineGrantDs driveOfflineGrantDs;
  late AuthRepositoryImpl repository;
  late MockGoogleSignInAccount account;

  AuthSessionBundle sampleBundle({
    String googleUserId = 'google-sub-123',
    List<String>? scopesGranted,
  }) =>
      AuthSessionBundle.create(
        googleUserId: googleUserId,
        email: 'merchant@example.com',
        serverClientId: 'web-client-id.apps.googleusercontent.com',
        scopesGranted: scopesGranted ?? AuthScopes.defaultDriveBackupScopes,
        linkedAt: DateTime.utc(2026, 6, 8, 12),
      );

  AuditLogModel sampleAuditLog() => AuditLogModel(
        id: 'audit-1',
        entityType: 'google_auth',
        entityId: 'google',
        action: 'LINKED',
        timestamp: DateTime.utc(2026, 6, 8),
        deviceId: 'device-1',
      );

  setUpAll(() {
    DeviceIdentity.initializeForTest('auth-repo-test-device');
    registerFallbackValue(const UpdateSettingsParams());
    registerFallbackValue(
      const HandleGoogleAccountChangeParams(
        oldEmail: 'old@example.com',
        newEmail: 'new@example.com',
        newAccountId: 'google-new',
      ),
    );
    registerFallbackValue(
      AuthSessionBundle.create(
        googleUserId: 'id',
        email: 'a@b.com',
        serverClientId: 'client',
        scopesGranted: const ['scope'],
        linkedAt: DateTime.utc(2026, 6, 8),
      ),
    );
    registerFallbackValue(sampleAuditLog());
    registerFallbackValue(MockGoogleSignInAccount());
    registerFallbackValue(DateTime.utc(2026, 7));
    registerFallbackValue(<String>[]);
  });

  setUp(() {
    googleAuthDs = MockGoogleAuthDs();
    authSessionStore = MockAuthSessionStore();
    settingsRepository = MockSettingsRepository();
    reconcileUseCase = MockReconcileDriftIdentityUseCase();
    handleAccountChangeUseCase = MockHandleGoogleAccountChangeUseCase();
    sessionBootstrapCoordinator = MockSessionBootstrapCoordinator();
    backupLocalDs = MockBackupLocalDs();
    backupQueueLocalDs = MockBackupQueueLocalDs();
    auditLogLocalDataSource = MockAuditLogLocalDataSource();
    driveOfflineGrantDs = StubDriveOfflineGrantDs();

    account = MockGoogleSignInAccount();
    when(() => account.id).thenReturn('google-sub-123');
    when(() => account.email).thenReturn('merchant@example.com');
    when(() => account.displayName).thenReturn('Merchant');
    when(() => account.photoUrl).thenReturn('https://example.com/photo.png');

    repository = AuthRepositoryImpl(
      googleAuthDs: googleAuthDs,
      authSessionStore: authSessionStore,
      settingsRepository: settingsRepository,
      reconcileDriftIdentityUseCase: reconcileUseCase,
      handleGoogleAccountChangeUseCase: handleAccountChangeUseCase,
      sessionBootstrapCoordinator: sessionBootstrapCoordinator,
      backupLocalDs: backupLocalDs,
      backupQueueLocalDs: backupQueueLocalDs,
      auditLogLocalDataSource: auditLogLocalDataSource,
      driveOfflineGrantDs: driveOfflineGrantDs,
    );
  });

  group('AuthRepositoryImpl', () {
    test('isSignedIn reads bundle only', () async {
      when(() => authSessionStore.read()).thenAnswer((_) async => sampleBundle());

      expect(await repository.isSignedIn(), isTrue);
      verifyNever(() => settingsRepository.get());
    });

    test('getSignedInAccount returns bundle googleUserId only', () async {
      when(() => authSessionStore.read()).thenAnswer((_) async => sampleBundle());

      final result = await repository.getSignedInAccount();

      expect(await expectRight(result), 'google-sub-123');
      verifyNever(() => googleAuthDs.getAccount());
    });

    test('getSessionState delegates to bootstrap coordinator', () async {
      when(() => sessionBootstrapCoordinator.execute()).thenAnswer(
        (_) async => const Right(AuthSessionState.linked),
      );

      expect(await repository.getSessionState(), AuthSessionState.linked);
    });

    test('getSessionState returns needsReauth when bootstrap fails but bundle exists',
        () async {
      when(() => sessionBootstrapCoordinator.execute()).thenAnswer(
        (_) async => const Left(DatabaseFailure('settings read failed')),
      );
      when(() => authSessionStore.read()).thenAnswer((_) async => sampleBundle());

      expect(
        await repository.getSessionState(),
        AuthSessionState.needsReauth,
      );
    });

    test('getSessionStateAfterInteractiveSignIn returns linked for warm SDK session',
        () async {
      final bundle = sampleBundle();
      when(() => authSessionStore.read()).thenAnswer((_) async => bundle);
      when(() => googleAuthDs.getAccount()).thenReturn(account);
      when(() => account.id).thenReturn(bundle.googleUserId);
      when(() => reconcileUseCase.execute(bundle))
          .thenAnswer((_) async => const Right(unit));

      expect(
        await repository.getSessionStateAfterInteractiveSignIn(),
        AuthSessionState.linked,
      );
      verifyNever(() => sessionBootstrapCoordinator.execute());
    });

    test('signInWithGoogle reconciles Drift and appends audit on success',
        () async {
      final bundle = sampleBundle();
      var readCount = 0;
      when(() => authSessionStore.read()).thenAnswer((_) async {
        readCount++;
        return readCount == 1 ? null : bundle;
      });
      when(() => settingsRepository.get())
          .thenAnswer((_) async => const Right(AppSettings()));
      when(() => googleAuthDs.signIn()).thenAnswer((_) async => account);
      when(() => googleAuthDs.persistSessionBundle(any()))
          .thenAnswer((_) async {});
      when(() => reconcileUseCase.execute(any()))
          .thenAnswer((_) async => const Right(unit));
      when(() => auditLogLocalDataSource.appendLog(any()))
          .thenAnswer((invocation) async => invocation.positionalArguments[0] as AuditLogModel);

      final result = await repository.signInWithGoogle();

      expect(await expectRight(result), unit);
      verify(() => googleAuthDs.persistSessionBundle(account)).called(1);
      // Offline PKCE must NOT run inside Sign In (causes dual Google UI loop).
      verifyNever(
        () => authSessionStore.updateDriveOfflineGrant(
          refreshToken: any(named: 'refreshToken'),
          clientId: any(named: 'clientId'),
        ),
      );
      verify(() => reconcileUseCase.execute(bundle)).called(1);
      verifyNever(() => settingsRepository.update(any()));
      verify(() => auditLogLocalDataSource.appendLog(any())).called(1);
      verifyNever(() => handleAccountChangeUseCase.call(any()));
    });

    test('signInWithGoogle triggers account switch purge when id changes',
        () async {
      final oldBundle = sampleBundle(googleUserId: 'old-google-id');
      final newBundle = sampleBundle();
      final ceremonyOrder = <String>[];
      var readCount = 0;
      when(() => authSessionStore.read()).thenAnswer((_) async {
        readCount++;
        return readCount == 1 ? oldBundle : newBundle;
      });
      when(() => settingsRepository.get()).thenAnswer(
        (_) async => const Right(
          AppSettings(
            googleAccountId: 'old-google-id',
            googleAccountEmail: 'old@example.com',
          ),
        ),
      );
      when(() => googleAuthDs.signIn()).thenAnswer((_) async => account);
      when(() => handleAccountChangeUseCase.call(any())).thenAnswer((_) async {
        ceremonyOrder.add('accountChange');
        return const Right(unit);
      });
      when(() => googleAuthDs.persistSessionBundle(any())).thenAnswer((_) async {
        ceremonyOrder.add('persist');
      });
      when(() => reconcileUseCase.execute(any()))
          .thenAnswer((_) async => const Right(unit));
      when(() => auditLogLocalDataSource.appendLog(any()))
          .thenAnswer((invocation) async => invocation.positionalArguments[0] as AuditLogModel);

      final result = await repository.signInWithGoogle();

      expect(await expectRight(result), unit);
      expect(ceremonyOrder, ['accountChange', 'persist']);
      verify(() => handleAccountChangeUseCase.call(any())).called(1);
      verify(() => googleAuthDs.persistSessionBundle(account)).called(1);
      verifyNever(
        () => authSessionStore.updateDriveOfflineGrant(
          refreshToken: any(named: 'refreshToken'),
          clientId: any(named: 'clientId'),
        ),
      );
    });

    test('signOut clears settings, stale Drive ids, and queue', () async {
      when(() => googleAuthDs.signOut()).thenAnswer((_) async {});
      when(() => settingsRepository.update(any())).thenAnswer(
        (_) async => const Right(AppSettings()),
      );
      when(() => backupLocalDs.clearAllGoogleDriveFileIds())
          .thenAnswer((_) async {});
      when(() => backupQueueLocalDs.clearAll()).thenAnswer((_) async {});
      when(() => auditLogLocalDataSource.appendLog(any()))
          .thenAnswer((invocation) async => invocation.positionalArguments[0] as AuditLogModel);

      final result = await repository.signOut();

      expect(await expectRight(result), unit);
      final captured = verify(() => settingsRepository.update(captureAny()))
          .captured
          .single as UpdateSettingsParams;
      expect(captured.clearGoogleAccount, isTrue);
      verify(() => backupLocalDs.clearAllGoogleDriveFileIds()).called(1);
      verify(() => backupQueueLocalDs.clearAll()).called(1);
      verify(() => auditLogLocalDataSource.appendLog(any())).called(1);
    });

    test('signInSilently skips SDK when bundle has valid cached token', () async {
      final bundle = sampleBundle().withCachedAccessToken('oauth-access-token');
      when(() => authSessionStore.read()).thenAnswer((_) async => bundle);

      final result = await repository.signInSilently();

      expect(await expectRight(result), unit);
      verifyNever(() => googleAuthDs.signInSilently());
      verifyNever(() => settingsRepository.get());
    });

    test(
      'signInSilently with linked bundle + PKCE unavailable does not call GSI',
      () async {
        final bundle = sampleBundle().withDriveOfflineGrant(
          refreshToken: 'refresh',
          clientId: 'android-client.apps.googleusercontent.com',
        );
        when(() => authSessionStore.read()).thenAnswer((_) async => bundle);
        when(() => googleAuthDs.ensureDriveCredential()).thenAnswer(
          (_) async => DriveCredentialStatus.unavailable,
        );

        final result = await repository.signInSilently();

        expect(
          result.fold((f) => f, (_) => null),
          isA<NetworkFailure>(),
        );
        verify(() => googleAuthDs.ensureDriveCredential()).called(1);
        verifyNever(() => googleAuthDs.signInSilently());
      },
    );

    test(
      'signInSilently with linked bundle without grant does not call GSI',
      () async {
        final bundle = sampleBundle();
        when(() => authSessionStore.read()).thenAnswer((_) async => bundle);

        final result = await repository.signInSilently();

        expect(result.isLeft(), isTrue);
        verifyNever(() => googleAuthDs.signInSilently());
        verifyNever(() => googleAuthDs.ensureDriveCredential());
      },
    );

    test('getGoogleAccountProfile returns bundle-backed profile', () async {
      final bundle = sampleBundle();
      when(() => authSessionStore.read()).thenAnswer((_) async => bundle);
      when(() => googleAuthDs.getAccount()).thenReturn(null);

      final result = await repository.getGoogleAccountProfile();

      final profile = await expectRight(result);
      expect(profile, isA<GoogleAccountProfile>());
      expect(profile?.id, bundle.googleUserId);
      expect(profile?.email, bundle.email);
    });

    test(
      'ensureLinkedIdToken returns cached token without lightweight restore',
      () async {
        when(() => googleAuthDs.obtainIdToken()).thenAnswer(
          (_) async => 'cached-id-token',
        );

        final result = await repository.ensureLinkedIdToken();

        expect(await expectRight(result), 'cached-id-token');
        verifyNever(() => googleAuthDs.hydrateLinkedIdToken());
        verifyNever(() => googleAuthDs.signIn());
      },
    );

    test(
      'ensureLinkedIdToken hydrates on user gesture and fail-closes on mismatch',
      () async {
        when(() => googleAuthDs.hydrateLinkedIdToken()).thenAnswer(
          (_) async => const LinkedIdTokenMismatch(),
        );

        final result = await repository.ensureLinkedIdToken(
          allowLightweightRestore: true,
        );

        expect(result.isLeft(), isTrue);
        expect(
          result.getLeft().toNullable()?.code,
          'agent_google_account_mismatch',
        );
        verifyNever(() => googleAuthDs.signIn());
      },
    );

    test(
      'ensureLinkedIdToken maps missing token to agent_id_token_missing',
      () async {
        when(() => googleAuthDs.hydrateLinkedIdToken()).thenAnswer(
          (_) async => const LinkedIdTokenMissing(),
        );

        final result = await repository.ensureLinkedIdToken(
          allowLightweightRestore: true,
        );

        expect(result.isLeft(), isTrue);
        expect(
          result.getLeft().toNullable()?.code,
          'agent_id_token_missing',
        );
      },
    );

    test(
      'ensureLinkedIdToken maps openid upgrade to agent_openid_grant_required',
      () async {
        when(() => googleAuthDs.hydrateLinkedIdToken()).thenAnswer(
          (_) async => const LinkedIdTokenNeedsOpenIdGrant(),
        );

        final result = await repository.ensureLinkedIdToken(
          allowLightweightRestore: true,
        );

        expect(result.isLeft(), isTrue);
        expect(
          result.getLeft().toNullable()?.code,
          kAgentOpenIdGrantRequiredCode,
        );
        verifyNever(() => googleAuthDs.signIn());
      },
    );

    test(
      'completeDriveAuthorization no-ops when openid PKCE grant exists',
      () async {
        final bundle = sampleBundle(
          scopesGranted: AuthScopes.pkceOfflineGrantScopes,
        ).withDriveOfflineGrant(
          refreshToken: 'pkce-refresh-token',
          clientId: 'android-client.apps.googleusercontent.com',
        );
        when(() => authSessionStore.read()).thenAnswer((_) async => bundle);

        final result = await repository.completeDriveAuthorization();

        expect(await expectRight(result), unit);
        expect(driveOfflineGrantDs.acquireCalls, 0);
        verifyNever(
          () => authSessionStore.updateDriveOfflineGrant(
            refreshToken: any(named: 'refreshToken'),
            clientId: any(named: 'clientId'),
          ),
        );
      },
    );

    test(
      'completeDriveAuthorization re-runs PKCE when Drive grant lacks openid',
      () async {
        final bundle = sampleBundle().withDriveOfflineGrant(
          refreshToken: 'legacy-refresh-token',
          clientId: 'android-client.apps.googleusercontent.com',
        );
        when(() => authSessionStore.read()).thenAnswer((_) async => bundle);
        when(
          () => authSessionStore.updateDriveOfflineGrant(
            refreshToken: any(named: 'refreshToken'),
            clientId: any(named: 'clientId'),
            scopesGranted: any(named: 'scopesGranted'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => authSessionStore.updateCachedAccessToken(
            any(),
            expiresAt: any(named: 'expiresAt'),
          ),
        ).thenAnswer((_) async {});
        when(() => auditLogLocalDataSource.appendLog(any())).thenAnswer(
          (invocation) async =>
              invocation.positionalArguments[0] as AuditLogModel,
        );

        final result = await repository.completeDriveAuthorization();

        expect(await expectRight(result), unit);
        expect(driveOfflineGrantDs.acquireCalls, 1);
        verify(
          () => authSessionStore.updateDriveOfflineGrant(
            refreshToken: 'offline-refresh-token',
            clientId: 'android-client.apps.googleusercontent.com',
            scopesGranted: AuthScopes.pkceOfflineGrantScopes,
          ),
        ).called(1);
      },
    );
  });
}

Future<T> expectRight<T>(FutureOr<Either<Failure, T>> resultOrFuture) async {
  final result = await resultOrFuture;
  return result.fold(
    (failure) => fail('Expected Right but got Left($failure)'),
    (value) => value,
  );
}
