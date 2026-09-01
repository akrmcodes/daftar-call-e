import 'package:daftar/application/auth/exchange_sync_token_use_case.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/services/sync_token_store.dart';
import 'package:daftar/domain/entities/google_account_profile.dart';
import 'package:daftar/domain/enums/auth_session_state.dart';
import 'package:daftar/domain/enums/feature_flag.dart';
import 'package:daftar/domain/repositories/activation_repository.dart';
import 'package:daftar/domain/repositories/auth_repository.dart';
import 'package:daftar/domain/repositories/sync_auth_bridge_repository.dart';
import 'package:daftar/presentation/providers/auth_providers.dart';
import 'package:daftar/presentation/providers/core_providers.dart';
import 'package:daftar/presentation/providers/sync_auth_bridge_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockActivationRepository extends Mock implements ActivationRepository {}

class MockExchangeSyncTokenUseCase extends Mock
    implements ExchangeSyncTokenUseCase {}

class MockSyncTokenStore extends Mock implements SyncTokenStore {}

final _validSyncCredentials = SyncAuthCredentials(
  syncToken: 'sync-jwt',
  workspaceId: 'ws-1',
  role: 'owner',
  obtainedAt: DateTime.utc(2026),
  expiresIn: 3600,
);

void main() {
  late MockAuthRepository authRepository;
  late MockActivationRepository activationRepository;
  late MockExchangeSyncTokenUseCase exchangeUseCase;
  late MockSyncTokenStore syncTokenStore;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    registerFallbackValue(
      const NetworkFailure('fallback', code: 'fallback'),
    );
    registerFallbackValue(FeatureFlag.multiDeviceSync);
  });

  setUp(() {
    authRepository = MockAuthRepository();
    activationRepository = MockActivationRepository();
    exchangeUseCase = MockExchangeSyncTokenUseCase();
    syncTokenStore = MockSyncTokenStore();
    when(() => syncTokenStore.read()).thenAnswer((_) async => null);
    when(
      () => activationRepository.isFeatureUnlocked(any()),
    ).thenAnswer((_) async => false);
    when(
      () => exchangeUseCase.ensureValid(
        allowInteractive: any(named: 'allowInteractive'),
      ),
    ).thenAnswer((_) async => Right(_validSyncCredentials));
  });

  ProviderContainer container0() {
    return ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(authRepository),
        activationRepositoryProvider.overrideWithValue(activationRepository),
        exchangeSyncTokenUseCaseProvider.overrideWithValue(exchangeUseCase),
        syncTokenStoreProvider.overrideWithValue(syncTokenStore),
      ],
    );
  }

  group('authStateProvider', () {
    test('emits linked when session bootstrap reports linked', () async {
      when(() => authRepository.getSessionState())
          .thenAnswer((_) async => AuthSessionState.linked);

      final container = container0();
      addTearDown(container.dispose);

      expect(
        await container.read(authStateProvider.future),
        AuthSessionState.linked,
      );
    });

    test('emits unlinked when no session bundle exists', () async {
      when(() => authRepository.getSessionState())
          .thenAnswer((_) async => AuthSessionState.unlinked);

      final container = container0();
      addTearDown(container.dispose);

      expect(
        await container.read(authStateProvider.future),
        AuthSessionState.unlinked,
      );
    });
  });

  group('googleAccountProvider', () {
    test('returns null when session is unlinked', () async {
      when(() => authRepository.getSessionState())
          .thenAnswer((_) async => AuthSessionState.unlinked);

      final container = container0();
      addTearDown(container.dispose);

      expect(await container.read(googleAccountProvider.future), isNull);
      verifyNever(() => authRepository.getGoogleAccountProfile());
    });

    test('returns profile from bundle when session needs reauth', () async {
      const profile = GoogleAccountProfile(
        id: 'google-1',
        email: 'merchant@example.com',
      );
      when(() => authRepository.getSessionState())
          .thenAnswer((_) async => AuthSessionState.needsReauth);
      when(() => authRepository.getGoogleAccountProfile()).thenAnswer(
        (_) async => const Right(profile),
      );

      final container = container0();
      addTearDown(container.dispose);

      expect(await container.read(googleAccountProvider.future), profile);
    });

    test('returns profile when session is linked', () async {
      const profile = GoogleAccountProfile(
        id: 'google-1',
        email: 'merchant@example.com',
      );
      when(() => authRepository.getSessionState())
          .thenAnswer((_) async => AuthSessionState.linked);
      when(() => authRepository.getGoogleAccountProfile()).thenAnswer(
        (_) async => const Right(profile),
      );

      final container = container0();
      addTearDown(container.dispose);

      expect(await container.read(googleAccountProvider.future), profile);
    });
  });

  group('signInControllerProvider', () {
    test('adopts linked state via fast path after successful sign-in', () async {
      when(() => authRepository.signInWithGoogle())
          .thenAnswer((_) async => const Right(unit));
      when(() => authRepository.getSessionStateAfterInteractiveSignIn())
          .thenAnswer((_) async => AuthSessionState.linked);
      when(() => authRepository.getGoogleAccountProfile()).thenAnswer(
        (_) async => const Right(
          GoogleAccountProfile(
            id: 'google-1',
            email: 'merchant@example.com',
          ),
        ),
      );

      final container = container0();
      addTearDown(container.dispose);

      final result = await container
          .read(signInControllerProvider.notifier)
          .signInWithGoogle();

      expect(result.isRight(), isTrue);
      expect(
        await container.read(authStateProvider.future),
        AuthSessionState.linked,
      );
      verify(() => authRepository.getSessionStateAfterInteractiveSignIn())
          .called(1);
      verifyNever(
        () => exchangeUseCase.ensureValid(allowInteractive: any(named: 'allowInteractive')),
      );
    });

    test(
      'returns Right when Google sign-in succeeds without sync bridge',
      () async {
        when(() => authRepository.signInWithGoogle())
            .thenAnswer((_) async => const Right(unit));
        when(() => authRepository.getSessionStateAfterInteractiveSignIn())
            .thenAnswer((_) async => AuthSessionState.linked);
        when(
          () => exchangeUseCase.ensureValid(),
        ).thenAnswer(
          (_) async => const Left(
            NetworkFailure('server down', code: '503'),
          ),
        );

        final container = container0();
        addTearDown(container.dispose);

        final result = await container
            .read(signInControllerProvider.notifier)
            .signInWithGoogle();

        expect(result.isRight(), isTrue);
        expect(
          await container.read(authStateProvider.future),
          AuthSessionState.linked,
        );
        expect(container.read(signInControllerProvider).isLoading, isFalse);
        verify(() => authRepository.signInWithGoogle()).called(1);
        verifyNever(
          () => exchangeUseCase.ensureValid(allowInteractive: any(named: 'allowInteractive')),
        );
      },
    );
  });
}
