import 'package:daftar/application/auth/ensure_pro_plus_sync_token_use_case.dart';
import 'package:daftar/application/auth/exchange_sync_token_use_case.dart';
import 'package:daftar/application/auth/resolve_workspace_role_use_case.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/services/sync_token_store.dart';
import 'package:daftar/data/repositories/sync_auth_bridge_repository_impl.dart';
import 'package:daftar/domain/repositories/sync_auth_bridge_repository.dart';
import 'package:daftar/presentation/providers/core_providers.dart';
import 'package:daftar/presentation/providers/sync_providers.dart';
import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'sync_auth_bridge_provider.g.dart';

/// Links Google Sign-In state to the custom Supabase sync JWT (Stage 8.2).
///
/// - [build] hydrates from [SyncTokenStore] when a valid token exists.
/// - [ensureSyncToken] returns a cached token or re-exchanges via the Edge
///   Function when expired or absent.
/// - [clear] revokes the sync credential on sign-out.
///
/// Stage 8.4 must call [ensureSyncToken] off the local CRUD critical path.
@Riverpod(keepAlive: true)
class SyncAuthBridge extends _$SyncAuthBridge {
  bool _exchangeBlocked = false;
  Failure? _lastBridgeFailure;

  @override
  Future<SyncTokenBundle?> build() async {
    return ref.read(syncTokenStoreProvider).read();
  }

  /// Returns a valid sync JWT, refreshing when expired.
  ///
  /// Free / Pro tiers without multi-device sync short-circuit immediately —
  /// [Right(null)] means sync is idle (not licensed). When the last exchange
  /// failed, subsequent calls short-circuit until [retry] unless [forceRetry].
  Future<Either<Failure, SyncTokenBundle?>> ensureSyncToken({
    bool allowInteractive = false,
    bool forceRetry = false,
  }) async {
    if (_exchangeBlocked && !forceRetry) {
      return Left(
        _lastBridgeFailure ??
            const NetworkFailure(
              'Sync server unreachable.',
              code: 'sync_bridge_blocked',
            ),
      );
    }

    final useCase = ref.read(ensureProPlusSyncTokenUseCaseProvider);
    final result = await useCase(allowInteractive: allowInteractive);

    if (!ref.mounted) {
      return result.map(_toBundleOrNull);
    }

    return await result.fold(
      (failure) async {
        _exchangeBlocked = true;
        _lastBridgeFailure = failure;
        state = AsyncError(failure, StackTrace.current);
        return Left<Failure, SyncTokenBundle?>(failure);
      },
      (credentials) async {
        _exchangeBlocked = false;
        _lastBridgeFailure = null;
        if (credentials == null) {
          final cached = await ref.read(syncTokenStoreProvider).read();
          if (ref.mounted) {
            state = AsyncData(cached);
          }
          if (cached != null && cached.isValid) {
            return Right<Failure, SyncTokenBundle?>(cached);
          }
          return const Right<Failure, SyncTokenBundle?>(null);
        }
        final bundle = _toBundle(credentials);
        if (ref.mounted) {
          state = AsyncData(bundle);
        }
        return Right<Failure, SyncTokenBundle?>(bundle);
      },
    );
  }

  /// Clears the circuit-breaker and retries the Auth Bridge exchange.
  ///
  /// Intended for explicit user taps only — never call from listeners.
  Future<Either<Failure, SyncTokenBundle?>> retry() {
    return ensureSyncToken(forceRetry: true);
  }

  /// Clears the stored sync token (sign-out).
  Future<void> clear() async {
    await ref.read(syncAuthBridgeRepositoryProvider).clear();
    _exchangeBlocked = false;
    _lastBridgeFailure = null;
    if (ref.mounted) {
      state = const AsyncData(null);
    }
  }

  static SyncTokenBundle? _toBundleOrNull(SyncAuthCredentials? credentials) {
    if (credentials == null) {
      return null;
    }
    return _toBundle(credentials);
  }

  static SyncTokenBundle _toBundle(SyncAuthCredentials credentials) {
    return SyncTokenBundle(
      syncToken: credentials.syncToken,
      workspaceId: credentials.workspaceId,
      role: credentials.role,
      obtainedAt: credentials.obtainedAt,
      expiresIn: credentials.expiresIn,
      identityHash: credentials.identityHash,
    );
  }
}

/// Domain repository for the Auth Bridge.
@Riverpod(keepAlive: true)
SyncAuthBridgeRepository syncAuthBridgeRepository(Ref ref) {
  return SyncAuthBridgeRepositoryImpl(
    googleAuthDs: ref.watch(googleAuthDsProvider),
    bridgeDs: ref.watch(supabaseAuthBridgeDsProvider),
    syncTokenStore: ref.watch(syncTokenStoreProvider),
  );
}

/// Application use case for the Auth Bridge exchange ceremony.
@Riverpod(keepAlive: true)
ExchangeSyncTokenUseCase exchangeSyncTokenUseCase(Ref ref) {
  return ExchangeSyncTokenUseCase(ref.watch(syncAuthBridgeRepositoryProvider));
}

/// Pro+ gated sync-token ensure (entitlement + exchange).
@Riverpod(keepAlive: true)
EnsureProPlusSyncTokenUseCase ensureProPlusSyncTokenUseCase(Ref ref) {
  return EnsureProPlusSyncTokenUseCase(
    isMultiDeviceSyncUnlocked: ref.watch(isMultiDeviceSyncUnlockedUseCaseProvider),
    syncAuthBridgeRepository: ref.watch(syncAuthBridgeRepositoryProvider),
  );
}

/// Offline-safe workspace role resolver.
@Riverpod(keepAlive: true)
ResolveWorkspaceRoleUseCase resolveWorkspaceRoleUseCase(Ref ref) {
  return ResolveWorkspaceRoleUseCase(
    syncAuthBridgeRepository: ref.watch(syncAuthBridgeRepositoryProvider),
  );
}
