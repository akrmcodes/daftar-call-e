import 'package:daftar/application/auth/finalize_drive_credentials_use_case.dart';
import 'package:daftar/core/services/auth_session_store.dart';
import 'package:daftar/domain/constants/auth_scopes.dart';
import 'package:daftar/domain/enums/auth_session_state.dart';
import 'package:daftar/domain/services/auth_silent_sign_in_gateway.dart';
import 'package:daftar/domain/value_objects/auth_session_bundle.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthSessionStore extends Mock implements AuthSessionStore {}

class MockAuthSilentSignInGateway extends Mock
    implements AuthSilentSignInGateway {}

void main() {
  setUpAll(() {
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

  late MockAuthSessionStore authSessionStore;
  late MockAuthSilentSignInGateway silentSignInGateway;
  late FinalizeDriveCredentialsUseCase useCase;

  AuthSessionBundle sampleBundle() => AuthSessionBundle.create(
        googleUserId: 'google-sub-123',
        email: 'merchant@example.com',
        serverClientId: 'web-client-id.apps.googleusercontent.com',
        scopesGranted: AuthScopes.defaultDriveBackupScopes,
        linkedAt: DateTime.utc(2026, 6, 8, 12),
      );

  setUp(() {
    authSessionStore = MockAuthSessionStore();
    silentSignInGateway = MockAuthSilentSignInGateway();
    useCase = FinalizeDriveCredentialsUseCase(
      authSessionStore,
      silentSignInGateway,
    );
  });

  group('FinalizeDriveCredentialsUseCase', () {
    test('no-ops when state is not linked', () async {
      await useCase.call(AuthSessionState.unlinked);

      verifyNever(() => authSessionStore.read());
      verifyNever(() => silentSignInGateway.attemptSilentRecovery(any()));
    });

    test('skips SDK when linked and cached token is valid', () async {
      final bundle = sampleBundle().withCachedAccessToken('token');
      when(() => authSessionStore.read()).thenAnswer((_) async => bundle);

      await useCase.call(AuthSessionState.linked);

      verify(() => authSessionStore.read()).called(1);
      verifyNever(() => silentSignInGateway.attemptSilentRecovery(any()));
    });

    test('delegates to silent gateway when linked but token expired', () async {
      final bundle = sampleBundle();
      when(() => authSessionStore.read()).thenAnswer((_) async => bundle);
      when(() => silentSignInGateway.attemptSilentRecovery(bundle))
          .thenAnswer((_) async => true);

      await useCase.call(AuthSessionState.linked);

      verify(() => silentSignInGateway.attemptSilentRecovery(bundle)).called(1);
    });

    test('no-ops when linked but bundle is absent', () async {
      when(() => authSessionStore.read()).thenAnswer((_) async => null);

      await useCase.call(AuthSessionState.linked);

      verifyNever(() => silentSignInGateway.attemptSilentRecovery(any()));
    });
  });
}
