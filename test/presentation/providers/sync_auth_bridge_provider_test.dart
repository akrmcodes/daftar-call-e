import 'package:daftar/application/auth/ensure_pro_plus_sync_token_use_case.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/services/sync_token_store.dart';
import 'package:daftar/domain/repositories/sync_auth_bridge_repository.dart';
import 'package:daftar/presentation/providers/core_providers.dart';
import 'package:daftar/presentation/providers/sync_auth_bridge_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockEnsureProPlusSyncTokenUseCase extends Mock
    implements EnsureProPlusSyncTokenUseCase {}

class MockSyncTokenStore extends Mock implements SyncTokenStore {}

class MockSyncAuthBridgeRepository extends Mock
    implements SyncAuthBridgeRepository {}

SyncTokenBundle _freshBundle() => SyncTokenBundle(
      syncToken: 'sync-jwt',
      workspaceId: 'ws-1',
      role: 'owner',
      obtainedAt: DateTime.now().toUtc(),
      expiresIn: 3600,
    );

SyncAuthCredentials _freshCredentials() => SyncAuthCredentials(
      syncToken: 'sync-jwt',
      workspaceId: 'ws-1',
      role: 'owner',
      obtainedAt: DateTime.now().toUtc(),
      expiresIn: 3600,
    );

void main() {
  late MockEnsureProPlusSyncTokenUseCase ensureUseCase;
  late MockSyncTokenStore syncTokenStore;
  late MockSyncAuthBridgeRepository syncAuthBridgeRepository;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  setUp(() {
    ensureUseCase = MockEnsureProPlusSyncTokenUseCase();
    syncTokenStore = MockSyncTokenStore();
    syncAuthBridgeRepository = MockSyncAuthBridgeRepository();
    when(() => syncTokenStore.read()).thenAnswer((_) async => null);
  });

  ProviderContainer container0() {
    return ProviderContainer(
      overrides: [
        ensureProPlusSyncTokenUseCaseProvider.overrideWithValue(ensureUseCase),
        syncTokenStoreProvider.overrideWithValue(syncTokenStore),
        syncAuthBridgeRepositoryProvider
            .overrideWithValue(syncAuthBridgeRepository),
      ],
    );
  }

  group('SyncAuthBridge.ensureSyncToken', () {
    test('short-circuits for Free tier without calling exchange', () async {
      when(
        () => ensureUseCase.call(
          allowInteractive: any(named: 'allowInteractive'),
        ),
      ).thenAnswer((_) async => const Right(null));

      final container = container0();
      addTearDown(container.dispose);

      final result = await container
          .read(syncAuthBridgeProvider.notifier)
          .ensureSyncToken();

      expect(result, const Right<Failure, SyncTokenBundle?>(null));
      verify(
        () => ensureUseCase.call(
          allowInteractive: any(named: 'allowInteractive'),
        ),
      ).called(1);
    });

    test('returns cached token for downgraded user without exchange', () async {
      final cached = _freshBundle();
      when(() => syncTokenStore.read()).thenAnswer((_) async => cached);
      when(
        () => ensureUseCase.call(
          allowInteractive: any(named: 'allowInteractive'),
        ),
      ).thenAnswer((_) async => const Right(null));

      final container = container0();
      addTearDown(container.dispose);

      final result = await container
          .read(syncAuthBridgeProvider.notifier)
          .ensureSyncToken();

      expect(result, Right<Failure, SyncTokenBundle?>(cached));
    });

    test('exchanges token for Pro+ tier', () async {
      final credentials = _freshCredentials();
      when(
        () => ensureUseCase.call(
          allowInteractive: any(named: 'allowInteractive'),
        ),
      ).thenAnswer((_) async => Right(credentials));

      final container = container0();
      addTearDown(container.dispose);

      final result = await container
          .read(syncAuthBridgeProvider.notifier)
          .ensureSyncToken();

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('expected success'),
        (bundle) => expect(bundle?.syncToken, 'sync-jwt'),
      );
      verify(
        () => ensureUseCase.call(
          allowInteractive: any(named: 'allowInteractive'),
        ),
      ).called(1);
    });

    test('circuit-breaker blocks repeat exchange after failure on Pro+', () async {
      when(
        () => ensureUseCase.call(
          allowInteractive: any(named: 'allowInteractive'),
        ),
      ).thenAnswer(
        (_) async => const Left(
          NetworkFailure('server down', code: '503'),
        ),
      );

      final container = container0();
      addTearDown(container.dispose);
      final bridge = container.read(syncAuthBridgeProvider.notifier);

      final first = await bridge.ensureSyncToken();
      expect(first.isLeft(), isTrue);

      final second = await bridge.ensureSyncToken();
      expect(second.isLeft(), isTrue);
      expect(
        second.fold((f) => f.code, (_) => null),
        '503',
      );

      verify(
        () => ensureUseCase.call(
          allowInteractive: any(named: 'allowInteractive'),
        ),
      ).called(1);
    });
  });
}
