import 'dart:async';

import 'package:daftar/application/auth/reconcile_drift_identity_use_case.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/constants/auth_scopes.dart';
import 'package:daftar/domain/entities/app_settings.dart';
import 'package:daftar/domain/repositories/settings_repository.dart';
import 'package:daftar/domain/value_objects/auth_session_bundle.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockSettingsRepository extends Mock implements SettingsRepository {}

void main() {
  late MockSettingsRepository settingsRepository;

  setUpAll(() {
    registerFallbackValue(const UpdateSettingsParams());
  });

  setUp(() {
    settingsRepository = MockSettingsRepository();
  });

  AuthSessionBundle sampleBundle() => AuthSessionBundle.create(
        googleUserId: 'google-sub-123',
        email: 'merchant@example.com',
        serverClientId: 'web-client-id.apps.googleusercontent.com',
        scopesGranted: AuthScopes.defaultDriveBackupScopes,
        linkedAt: DateTime.utc(2026, 6, 8, 12),
      );

  group('ReconcileDriftIdentityUseCase', () {
    test('skips update when Drift already matches bundle', () async {
      final bundle = sampleBundle();
      final useCase = ReconcileDriftIdentityUseCase(settingsRepository);

      when(() => settingsRepository.get()).thenAnswer(
        (_) async => Right(
          AppSettings(
            googleAccountId: bundle.googleUserId,
            googleAccountEmail: bundle.email,
          ),
        ),
      );

      final result = await useCase.execute(bundle);

      expect(await expectRight(result), unit);
      verifyNever(() => settingsRepository.update(any()));
    });

    test('overwrites stale Drift id and email when bundle disagrees', () async {
      final bundle = sampleBundle();
      final useCase = ReconcileDriftIdentityUseCase(settingsRepository);

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

      final result = await useCase.execute(bundle);

      expect(await expectRight(result), unit);
      final captured = verify(() => settingsRepository.update(captureAny()))
          .captured
          .single as UpdateSettingsParams;
      expect(captured.googleAccountId, bundle.googleUserId);
      expect(captured.googleAccountEmail, bundle.email);
      expect(captured.clearGoogleAccount, isFalse);
    });

    test('overwrites stale Drift email when id already matches bundle', () async {
      final bundle = sampleBundle();
      final useCase = ReconcileDriftIdentityUseCase(settingsRepository);

      when(() => settingsRepository.get()).thenAnswer(
        (_) async => Right(
          AppSettings(
            googleAccountId: bundle.googleUserId,
            googleAccountEmail: 'stale-email@example.com',
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

      final result = await useCase.execute(bundle);

      expect(await expectRight(result), unit);
      final captured = verify(() => settingsRepository.update(captureAny()))
          .captured
          .single as UpdateSettingsParams;
      expect(captured.googleAccountId, bundle.googleUserId);
      expect(captured.googleAccountEmail, bundle.email);
    });

    test('returns failure when settings cannot be read', () async {
      final useCase = ReconcileDriftIdentityUseCase(settingsRepository);

      when(() => settingsRepository.get()).thenAnswer(
        (_) async => const Left(
          DatabaseFailure('read failed', code: 'database_error'),
        ),
      );

      final result = await useCase.execute(sampleBundle());

      final failure = await expectLeft(result);
      expect(failure, isA<DatabaseFailure>());
      verifyNever(() => settingsRepository.update(any()));
    });

    test('overwrites empty Drift Google fields from bundle', () async {
      final bundle = sampleBundle();
      final useCase = ReconcileDriftIdentityUseCase(settingsRepository);

      when(() => settingsRepository.get()).thenAnswer(
        (_) async => const Right(AppSettings()),
      );
      when(() => settingsRepository.update(any())).thenAnswer(
        (_) async => Right(
          AppSettings(
            googleAccountId: bundle.googleUserId,
            googleAccountEmail: bundle.email,
          ),
        ),
      );

      final result = await useCase.execute(bundle);

      expect(await expectRight(result), unit);
      final captured = verify(() => settingsRepository.update(captureAny()))
          .captured
          .single as UpdateSettingsParams;
      expect(captured.googleAccountId, bundle.googleUserId);
      expect(captured.googleAccountEmail, bundle.email);
      expect(captured.clearGoogleAccount, isFalse);
    });

    test('overwrites null Drift email when id already matches bundle', () async {
      final bundle = sampleBundle();
      final useCase = ReconcileDriftIdentityUseCase(settingsRepository);

      when(() => settingsRepository.get()).thenAnswer(
        (_) async => Right(
          AppSettings(googleAccountId: bundle.googleUserId),
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

      final result = await useCase.execute(bundle);

      expect(await expectRight(result), unit);
      final captured = verify(() => settingsRepository.update(captureAny()))
          .captured
          .single as UpdateSettingsParams;
      expect(captured.googleAccountEmail, bundle.email);
      expect(captured.clearGoogleAccount, isFalse);
    });

    test('double execute is idempotent when Drift already matches', () async {
      final bundle = sampleBundle();
      final useCase = ReconcileDriftIdentityUseCase(settingsRepository);

      when(() => settingsRepository.get()).thenAnswer(
        (_) async => Right(
          AppSettings(
            googleAccountId: bundle.googleUserId,
            googleAccountEmail: bundle.email,
          ),
        ),
      );

      await useCase.execute(bundle);
      await useCase.execute(bundle);

      verifyNever(() => settingsRepository.update(any()));
    });

    test('returns failure when settings update fails', () async {
      final useCase = ReconcileDriftIdentityUseCase(settingsRepository);

      when(() => settingsRepository.get()).thenAnswer(
        (_) async => const Right(AppSettings(googleAccountId: 'stale-id')),
      );
      when(() => settingsRepository.update(any())).thenAnswer(
        (_) async => const Left(
          DatabaseFailure('write failed', code: 'database_error'),
        ),
      );

      final result = await useCase.execute(sampleBundle());

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
