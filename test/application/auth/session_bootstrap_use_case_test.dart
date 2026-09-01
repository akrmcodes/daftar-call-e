import 'dart:async';

import 'package:daftar/application/auth/reconcile_drift_identity_use_case.dart';
import 'package:daftar/application/auth/session_bootstrap_use_case.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/services/auth_session_store.dart';
import 'package:daftar/domain/constants/auth_scopes.dart';
import 'package:daftar/domain/entities/app_settings.dart';
import 'package:daftar/domain/enums/auth_session_state.dart';
import 'package:daftar/domain/repositories/settings_repository.dart';
import 'package:daftar/domain/services/auth_silent_sign_in_gateway.dart';
import 'package:daftar/domain/value_objects/auth_session_bundle.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockSettingsRepository extends Mock implements SettingsRepository {}

class MockAuthSilentSignInGateway extends Mock
    implements AuthSilentSignInGateway {}

class MockReconcileDriftIdentityUseCase extends Mock
    implements ReconcileDriftIdentityUseCase {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, String> vault;
  late AuthSessionStore authSessionStore;
  late MockSettingsRepository settingsRepository;
  late MockAuthSilentSignInGateway silentSignInGateway;
  late MockReconcileDriftIdentityUseCase reconcileUseCase;

  setUpAll(() {
    registerFallbackValue(const UpdateSettingsParams());
    registerFallbackValue(
      AuthSessionBundle.create(
        googleUserId: 'id',
        email: 'a@b.com',
        serverClientId: 'client',
        scopesGranted: const ['scope'],
        linkedAt: DateTime.utc(2026, 6, 8),
      ),
    );
  });

  setUp(() {
    vault = <String, String>{};
    FlutterSecureStoragePlatform.instance =
        TestFlutterSecureStoragePlatform(vault);
    authSessionStore = AuthSessionStore(storage: const FlutterSecureStorage());
    settingsRepository = MockSettingsRepository();
    silentSignInGateway = MockAuthSilentSignInGateway();
    reconcileUseCase = MockReconcileDriftIdentityUseCase();
  });

  SessionBootstrapUseCase createUseCase() => SessionBootstrapUseCase(
        authSessionStore,
        settingsRepository,
        silentSignInGateway,
        reconcileUseCase,
      );

  AuthSessionBundle sampleBundle() => AuthSessionBundle.create(
        googleUserId: 'google-sub-123',
        email: 'merchant@example.com',
        serverClientId: 'web-client-id.apps.googleusercontent.com',
        scopesGranted: AuthScopes.defaultDriveBackupScopes,
        linkedAt: DateTime.utc(2026, 6, 8, 12),
      );

  void stubSettings({String? googleAccountId, String? googleAccountEmail}) {
    when(() => settingsRepository.get()).thenAnswer(
      (_) async => Right(
        AppSettings(
          googleAccountId: googleAccountId,
          googleAccountEmail: googleAccountEmail,
        ),
      ),
    );
  }

  group('SessionBootstrapUseCase', () {
    group('state machine — four bootstrap outcomes', () {
      test('unlinked: no bundle and no Drift googleAccountId', () async {
        stubSettings();
        final useCase = createUseCase();

        final result = await useCase.execute();

        expect(await expectRight(result), AuthSessionState.unlinked);
        verifyNever(() => silentSignInGateway.attemptSilentRecovery(any()));
      });

      test('unlinked: whitespace-only Drift id is not a ghost', () async {
        stubSettings(googleAccountId: '   ');
        final useCase = createUseCase();

        final result = await useCase.execute();

        expect(await expectRight(result), AuthSessionState.unlinked);
        verifyNever(() => silentSignInGateway.attemptSilentRecovery(any()));
      });

      test('migrationRelinkRequired: Drift ghost id without bundle', () async {
        stubSettings(googleAccountId: 'ghost-from-v1');
        final useCase = createUseCase();

        final result = await useCase.execute();

        expect(
          await expectRight(result),
          AuthSessionState.migrationRelinkRequired,
        );
        verifyNever(() => silentSignInGateway.attemptSilentRecovery(any()));
      });

      test(
          'migrationRelinkRequired: Drift ghost id and email without bundle',
          () async {
        stubSettings(
          googleAccountId: 'ghost-from-v1',
          googleAccountEmail: 'ghost@example.com',
        );
        final useCase = createUseCase();

        final result = await useCase.execute();

        expect(
          await expectRight(result),
          AuthSessionState.migrationRelinkRequired,
        );
        verifyNever(() => silentSignInGateway.attemptSilentRecovery(any()));
      });

      test(
          'needsReauth: expired cached token and silent recovery returns false',
          () async {
        final bundle = sampleBundle().withCachedAccessToken(
          'expired-token',
          expiresAt: DateTime.now().toUtc().subtract(const Duration(hours: 1)),
        );
        await authSessionStore.write(bundle);
        stubSettings();
        when(() => silentSignInGateway.attemptSilentRecovery(any()))
            .thenAnswer((_) async => false);
        final useCase = createUseCase();

        final result = await useCase.execute();

        expect(await expectRight(result), AuthSessionState.needsReauth);
        verify(() => silentSignInGateway.attemptSilentRecovery(bundle)).called(1);
        verifyNever(() => reconcileUseCase.execute(any()));
      });

      test('needsReauth: bundle present but silent recovery returns false',
          () async {
        await authSessionStore.write(sampleBundle());
        stubSettings();
        when(() => silentSignInGateway.attemptSilentRecovery(any()))
            .thenAnswer((_) async => false);
        final useCase = createUseCase();

        final result = await useCase.execute();

        expect(await expectRight(result), AuthSessionState.needsReauth);
        verify(() => silentSignInGateway.attemptSilentRecovery(any())).called(1);
        verifyNever(() => reconcileUseCase.execute(any()));
        final restored = await authSessionStore.read();
        expect(restored?.lastSuccessfulSilentAuthAt, isNull);
      });

      test('needsReauth: bundle present but silent recovery throws', () async {
        await authSessionStore.write(sampleBundle());
        stubSettings();
        when(() => silentSignInGateway.attemptSilentRecovery(any()))
            .thenThrow(StateError('sdk unavailable'));
        final useCase = createUseCase();

        final result = await useCase.execute();

        expect(await expectRight(result), AuthSessionState.needsReauth);
        verifyNever(() => reconcileUseCase.execute(any()));
      });

      test('linked: valid cached access token without silent SDK recovery',
          () async {
        final bundle = sampleBundle().withCachedAccessToken('oauth-access-token');
        await authSessionStore.write(bundle);
        stubSettings();
        when(() => reconcileUseCase.execute(any()))
            .thenAnswer((_) async => const Right(unit));
        final useCase = createUseCase();

        final result = await useCase.execute();

        expect(await expectRight(result), AuthSessionState.linked);
        verifyNever(() => silentSignInGateway.attemptSilentRecovery(any()));
        verify(() => reconcileUseCase.execute(bundle)).called(1);
      });

      test('needsReauth: grant-less silent recovery times out on cold start',
          () async {
        final bundle = sampleBundle();
        await authSessionStore.write(bundle);
        stubSettings();
        when(() => silentSignInGateway.attemptSilentRecovery(any())).thenAnswer(
          (_) => Future<bool>.delayed(
            const Duration(seconds: 10),
            () => true,
          ),
        );
        final useCase = createUseCase();

        final result = await useCase.execute();

        expect(await expectRight(result), AuthSessionState.needsReauth);
      });

      test(
          'linked: expired token with successful silent recovery updates timestamp',
          () async {
        final bundle = sampleBundle().withCachedAccessToken(
          'expired-token',
          expiresAt: DateTime.now().toUtc().subtract(const Duration(hours: 1)),
        );
        await authSessionStore.write(bundle);
        stubSettings();
        when(() => silentSignInGateway.attemptSilentRecovery(any()))
            .thenAnswer((_) async => true);
        when(() => reconcileUseCase.execute(any()))
            .thenAnswer((_) async => const Right(unit));
        final useCase = createUseCase();

        final result = await useCase.execute();

        expect(await expectRight(result), AuthSessionState.linked);
        final restored = await authSessionStore.read();
        expect(restored?.lastSuccessfulSilentAuthAt, isNotNull);
      });

      test('linked: silent recovery succeeds and reconcile completes', () async {
        final bundle = sampleBundle();
        await authSessionStore.write(bundle);
        stubSettings(googleAccountId: 'stale-id');
        when(() => silentSignInGateway.attemptSilentRecovery(any()))
            .thenAnswer((_) async => true);
        when(() => reconcileUseCase.execute(any()))
            .thenAnswer((_) async => const Right(unit));
        final useCase = createUseCase();

        final result = await useCase.execute();

        expect(await expectRight(result), AuthSessionState.linked);
        verify(() => silentSignInGateway.attemptSilentRecovery(bundle)).called(1);
        verify(() => reconcileUseCase.execute(bundle)).called(1);

        final restored = await authSessionStore.read();
        expect(restored?.lastSuccessfulSilentAuthAt, isNotNull);
      });
    });

    test('linked path reconciles stale Drift through real reconcile use case',
        () async {
      final bundle = sampleBundle();
      await authSessionStore.write(bundle);
      when(() => settingsRepository.get()).thenAnswer(
        (_) async => const Right(
          AppSettings(
            googleAccountId: 'stale-ghost-id',
            googleAccountEmail: 'old@example.com',
          ),
        ),
      );
      when(() => settingsRepository.update(any())).thenAnswer(
        (_) async => Right(
          AppSettings(
            googleAccountId: bundle.googleUserId,
            googleAccountEmail: bundle.email,
          ),
        ),
      );
      when(() => silentSignInGateway.attemptSilentRecovery(any()))
          .thenAnswer((_) async => true);

      final useCase = SessionBootstrapUseCase(
        authSessionStore,
        settingsRepository,
        silentSignInGateway,
        ReconcileDriftIdentityUseCase(settingsRepository),
      );

      final result = await useCase.execute();

      expect(await expectRight(result), AuthSessionState.linked);
      final captured = verify(() => settingsRepository.update(captureAny()))
          .captured
          .single as UpdateSettingsParams;
      expect(captured.googleAccountId, bundle.googleUserId);
      expect(captured.googleAccountEmail, bundle.email);
    });

    test('returns failure when reconcile fails with valid cached token', () async {
      final bundle = sampleBundle().withCachedAccessToken('oauth-access-token');
      await authSessionStore.write(bundle);
      stubSettings();
      when(() => reconcileUseCase.execute(any())).thenAnswer(
        (_) async => const Left(
          DatabaseFailure('reconcile failed', code: 'database_error'),
        ),
      );
      final useCase = createUseCase();

      final result = await useCase.execute();

      final failure = await expectLeft(result);
      expect(failure, isA<DatabaseFailure>());
      verifyNever(() => silentSignInGateway.attemptSilentRecovery(any()));
    });

    test('reads settings exactly once per bootstrap', () async {
      stubSettings();
      final useCase = createUseCase();

      await useCase.execute();

      verify(() => settingsRepository.get()).called(1);
    });

    test('returns failure when settings cannot be read', () async {
      when(() => settingsRepository.get()).thenAnswer(
        (_) async => const Left(
          DatabaseFailure('read failed', code: 'database_error'),
        ),
      );
      final useCase = createUseCase();

      final result = await useCase.execute();

      final failure = await expectLeft(result);
      expect(failure, isA<DatabaseFailure>());
    });

    test('returns failure when reconcile fails on linked path', () async {
      await authSessionStore.write(sampleBundle());
      stubSettings();
      when(() => silentSignInGateway.attemptSilentRecovery(any()))
          .thenAnswer((_) async => true);
      when(() => reconcileUseCase.execute(any())).thenAnswer(
        (_) async => const Left(
          DatabaseFailure('reconcile failed', code: 'database_error'),
        ),
      );
      final useCase = createUseCase();

      final result = await useCase.execute();

      final failure = await expectLeft(result);
      expect(failure, isA<DatabaseFailure>());
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

Future<Failure> expectLeft<T>(FutureOr<Either<Failure, T>> resultOrFuture) async {
  final result = await resultOrFuture;
  return result.fold(
    (failure) => failure,
    (value) => fail('Expected Left but got Right($value)'),
  );
}
