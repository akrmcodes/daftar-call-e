import 'dart:async';

import 'package:daftar/application/sync/pull_and_merge_use_case.dart';
import 'package:daftar/application/sync/push_pending_ops_use_case.dart';
import 'package:daftar/application/sync/start_sync_engine_use_case.dart';
import 'package:daftar/application/sync/stop_sync_engine_use_case.dart';
import 'package:daftar/application/sync/sync_now_use_case.dart';
import 'package:daftar/core/debug/agent_debug_log.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/services/connectivity_service.dart';
import 'package:daftar/core/services/device_identity_store.dart';
import 'package:daftar/data/datasources/local/sync_outbound_ack_local_ds.dart';
import 'package:daftar/data/datasources/remote/shared_account_sync_client.dart';
import 'package:daftar/data/datasources/remote/sync_remote_ds.dart';
import 'package:daftar/data/repositories/sync_engine_repository_impl.dart';
import 'package:daftar/domain/entities/merge_result.dart';
import 'package:daftar/domain/enums/workspace_role.dart';
import 'package:daftar/domain/repositories/sync_engine_repository.dart';
import 'package:daftar/presentation/providers/connectivity_providers.dart';
import 'package:daftar/presentation/providers/core_providers.dart';
import 'package:daftar/presentation/providers/sync_auth_bridge_provider.dart';
import 'package:daftar/presentation/providers/sync_providers.dart';
import 'package:flutter/widgets.dart';
import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'sync_engine_providers.g.dart';

/// Connectivity-driven sync orchestrator (Stage 8.4).
///
/// Never blocks local CRUD — sync token exchange and push/pull run only
/// inside this keepAlive controller.
@Riverpod(keepAlive: true)
class SyncEngineController extends _$SyncEngineController {
  static const _wakeupDebounce = Duration(milliseconds: 400);
  static const _mutationDebounce = Duration(milliseconds: 500);

  StreamSubscription<ConnectivityStatus>? _connectivitySub;
  StreamSubscription<void>? _realtimeSub;
  Timer? _wakeupDebounceTimer;
  Timer? _mutationDebounceTimer;
  _SyncLifecycleObserver? _lifecycleObserver;
  bool _syncInFlight = false;

  @override
  Future<void> build() async {
    ref.onDispose(_dispose);

    final entitled =
        await ref.read(isMultiDeviceSyncUnlockedUseCaseProvider).call();
    if (!entitled) {
      return;
    }

    _connectivitySub = ref
        .read(connectivityServiceProvider)
        .watchStatus()
        .listen(_onConnectivityChanged);

    final syncEngineRepo = ref.read(syncEngineRepositoryProvider);
    _realtimeSub = syncEngineRepo.changeWakeups.listen(_onRealtimeWakeup);

    _lifecycleObserver = _SyncLifecycleObserver(_onAppResumed);
    WidgetsBinding.instance.addObserver(_lifecycleObserver!);

    ref.listen(syncAuthBridgeProvider, (_, next) {});

    if (await ref.read(connectivityServiceProvider).currentStatus() ==
        ConnectivityStatus.online) {
      unawaited(_runSyncCycle(manual: false));
    }
  }

  /// Debounced push/pull after a local mutation (never blocks CRUD).
  void requestSyncAfterLocalMutation() {
    _mutationDebounceTimer?.cancel();
    _mutationDebounceTimer = Timer(_mutationDebounce, () {
      unawaited(_requestSyncAfterLocalMutationImpl());
    });
  }

  /// Manual Sync Now from Sync Report or settings.
  ///
  /// Returns a [Failure] when auth/sync aborts so the UI can show feedback.
  Future<Either<Failure, Unit>> syncNow() async {
    final entitled =
        await ref.read(isMultiDeviceSyncUnlockedUseCaseProvider).call();
    if (!entitled) {
      return const Left(
        AuthFailure(
          'Multi-device sync is not unlocked.',
          code: 'sync_not_entitled',
        ),
      );
    }
    return _runSyncCycle(manual: true);
  }

  /// Push pending local ops only (diagnostic Upload).
  Future<Either<Failure, int>> pushNow() async {
    // Claim the slot before the first await — a check-then-act guard lets two
    // triggers (resume + connectivity) both enter and double-push.
    if (!_claimSyncSlot()) {
      return const Left(
        NetworkFailure('Sync already in progress', code: 'sync_in_flight'),
      );
    }

    try {
      final entitled =
          await ref.read(isMultiDeviceSyncUnlockedUseCaseProvider).call();
      if (!entitled) {
        return const Left(
          AuthFailure(
            'Multi-device sync is not unlocked.',
            code: 'sync_not_entitled',
          ),
        );
      }

      if (await ref.read(connectivityServiceProvider).currentStatus() !=
          ConnectivityStatus.online) {
        return const Left(
          NetworkFailure('Device is offline', code: 'sync_offline'),
        );
      }

      final auth = await _ensureAuthenticated(
        manual: true,
        requireWritable: true,
      );
      return await auth.fold(
        (failure) async {
          AgentDebugLog.write(
            location: 'sync_engine_providers.dart:pushNow',
            message: 'push_auth_failed',
            hypothesisId: 'H2-auth-context',
            data: <String, Object?>{
              'failureCode': failure.code,
              'failureType': failure.runtimeType.toString(),
            },
          );
          return Left(failure);
        },
        (ctx) async {
          final result = await ref.read(pushPendingOpsUseCaseProvider)(
            syncJwt: ctx.syncJwt,
            workspaceRole:
                ctx.resolvedRole ?? WorkspaceRole.fromString(ctx.workspaceRole),
          );
          return result.fold(
            Left.new,
            (count) {
              if (ref.mounted) {
                ref.invalidate(syncStatusProvider);
              }
              return Right(count);
            },
          );
        },
      );
    } finally {
      _syncInFlight = false;
    }
  }

  /// Pull remote ops and merge only (diagnostic Download).
  Future<Either<Failure, MergeResult>> pullNow() async {
    if (!_claimSyncSlot()) {
      return const Left(
        NetworkFailure('Sync already in progress', code: 'sync_in_flight'),
      );
    }

    try {
      final entitled =
          await ref.read(isMultiDeviceSyncUnlockedUseCaseProvider).call();
      if (!entitled) {
        return const Left(
          AuthFailure(
            'Multi-device sync is not unlocked.',
            code: 'sync_not_entitled',
          ),
        );
      }

      if (await ref.read(connectivityServiceProvider).currentStatus() !=
          ConnectivityStatus.online) {
        return const Left(
          NetworkFailure('Device is offline', code: 'sync_offline'),
        );
      }

      final auth = await _ensureAuthenticated(
        manual: true,
        requireWritable: false,
      );
      return await auth.fold(
        (failure) async => Left(failure),
        (ctx) async {
          final result = await ref.read(pullAndMergeUseCaseProvider)(
            syncJwt: ctx.syncJwt,
          );
          return result.fold(
            Left.new,
            (merge) {
              if (ref.mounted) {
                ref
                  ..invalidate(syncStatusProvider)
                  ..invalidate(unresolvedConflictsProvider);
              }
              return Right(merge);
            },
          );
        },
      );
    } finally {
      _syncInFlight = false;
    }
  }

  /// Claims the single-flight slot synchronously, before any suspension point.
  bool _claimSyncSlot() {
    if (_syncInFlight) {
      return false;
    }
    _syncInFlight = true;
    return true;
  }

  Future<void> _requestSyncAfterLocalMutationImpl() async {
    if (_syncInFlight) {
      return;
    }
    final entitled =
        await ref.read(isMultiDeviceSyncUnlockedUseCaseProvider).call();
    if (!entitled) {
      return;
    }
    if (await ref.read(connectivityServiceProvider).currentStatus() !=
        ConnectivityStatus.online) {
      return;
    }
    unawaited(_runSyncCycle(manual: false));
  }

  void _onAppResumed() {
    unawaited(_requestSyncAfterLocalMutationImpl());
  }

  Future<Either<Failure, _SyncAuthContext>> _ensureAuthenticated({
    required bool manual,
    required bool requireWritable,
  }) async {
    final tokenResult = await ref
        .read(syncAuthBridgeProvider.notifier)
        .ensureSyncToken(
          allowInteractive: manual,
          forceRetry: manual,
        );

    if (!ref.mounted) {
      return const Left(
        NetworkFailure('Sync cancelled', code: 'sync_unmounted'),
      );
    }

    return tokenResult.fold(
      Left.new,
      (bundle) async {
        if (bundle == null || !bundle.isValid) {
          return const Left(
            AuthFailure(
              'Sync token unavailable. Sign in with Google and try again.',
              code: 'sync_token_missing',
            ),
          );
        }

        final role = await ref.read(resolveWorkspaceRoleUseCaseProvider).call();
        if (!ref.mounted) {
          return const Left(
            NetworkFailure('Sync cancelled', code: 'sync_unmounted'),
          );
        }

        if (requireWritable && role == WorkspaceRole.viewer) {
          return const Left(
            AuthFailure(
              'Viewer role cannot push sync changes.',
              code: 'sync_viewer_blocked',
            ),
          );
        }

        return Right(
          _SyncAuthContext(
            syncJwt: bundle.syncToken,
            workspaceRole: role?.name ?? bundle.role,
            workspaceId: bundle.workspaceId,
            deviceId: DeviceIdentity.current,
            resolvedRole: role,
          ),
        );
      },
    );
  }

  void _onConnectivityChanged(ConnectivityStatus status) {
    if (status == ConnectivityStatus.online) {
      unawaited(_runSyncCycle(manual: false));
    }
  }

  void _onRealtimeWakeup(void _) {
    _wakeupDebounceTimer?.cancel();
    _wakeupDebounceTimer = Timer(_wakeupDebounce, () {
      unawaited(_runSyncCycle(manual: false));
    });
  }

  Future<Either<Failure, Unit>> _runSyncCycle({required bool manual}) async {
    if (!_claimSyncSlot()) {
      return const Left(
        NetworkFailure('Sync already in progress', code: 'sync_in_flight'),
      );
    }

    try {
      if (await ref.read(connectivityServiceProvider).currentStatus() !=
          ConnectivityStatus.online) {
        return const Left(
          NetworkFailure('Device is offline', code: 'sync_offline'),
        );
      }

      final auth = await _ensureAuthenticated(
        manual: manual,
        requireWritable: manual,
      );

      if (!ref.mounted) {
        return const Left(
          NetworkFailure('Sync cancelled', code: 'sync_unmounted'),
        );
      }

      return await auth.fold(
        (failure) async => Left(failure),
        (ctx) async {
          final role = ctx.resolvedRole ??
              WorkspaceRole.fromString(ctx.workspaceRole);
          final isViewer = role == WorkspaceRole.viewer;

          if (isViewer) {
            final pullResult = await ref.read(pullAndMergeUseCaseProvider)(
              syncJwt: ctx.syncJwt,
            );
            return pullResult.fold(
              Left.new,
              (_) async {
                if (!ref.mounted) {
                  return const Right(unit);
                }
                await _ensureRealtimeStarted(ctx);
                ref
                  ..invalidate(syncStatusProvider)
                  ..invalidate(unresolvedConflictsProvider);
                return const Right(unit);
              },
            );
          }

          final syncNowUseCase = ref.read(syncNowUseCaseProvider);
          final result = await syncNowUseCase(
            syncJwt: ctx.syncJwt,
            workspaceRole: ctx.workspaceRole,
            workspaceId: ctx.workspaceId,
          );

          return result.fold(
            Left.new,
            (_) async {
              if (!ref.mounted) {
                return const Right(unit);
              }

              await _ensureRealtimeStarted(ctx);

              ref
                ..invalidate(syncStatusProvider)
                ..invalidate(unresolvedConflictsProvider);
              return const Right(unit);
            },
          );
        },
      );
    } finally {
      _syncInFlight = false;
    }
  }

  Future<void> _ensureRealtimeStarted(_SyncAuthContext ctx) async {
    final role =
        ctx.resolvedRole ?? await ref.read(resolveWorkspaceRoleUseCaseProvider).call();
    await ref.read(startSyncEngineUseCaseProvider)(
      syncJwt: ctx.syncJwt,
      workspaceId: ctx.workspaceId,
      workspaceRole: role,
    );
  }

  Future<void> _dispose() async {
    _wakeupDebounceTimer?.cancel();
    _mutationDebounceTimer?.cancel();
    if (_lifecycleObserver != null) {
      WidgetsBinding.instance.removeObserver(_lifecycleObserver!);
      _lifecycleObserver = null;
    }
    await _connectivitySub?.cancel();
    await _realtimeSub?.cancel();
    final stopUseCase = ref.read(stopSyncEngineUseCaseProvider);
    await stopUseCase();
  }
}

class _SyncLifecycleObserver extends WidgetsBindingObserver {
  _SyncLifecycleObserver(this._onResumed);

  final VoidCallback _onResumed;

  /// Ignores inactive→resumed (screenshot / overlays); only real background.
  bool _sawBackgroundPause = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _sawBackgroundPause = true;
      case AppLifecycleState.resumed:
        if (!_sawBackgroundPause) {
          return;
        }
        _sawBackgroundPause = false;
        _onResumed();
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }
}

class _SyncAuthContext {
  const _SyncAuthContext({
    required this.syncJwt,
    required this.workspaceRole,
    required this.workspaceId,
    required this.deviceId,
    this.resolvedRole,
  });

  final String syncJwt;
  final String workspaceRole;
  final String workspaceId;
  final String deviceId;
  final WorkspaceRole? resolvedRole;
}

/// Provides [SyncEngineRepository].
@Riverpod(keepAlive: true)
SyncEngineRepository syncEngineRepository(Ref ref) {
  return SyncEngineRepositoryImpl(
    remoteDs: ref.watch(syncRemoteDsProvider),
    mergeEngineRepository: ref.watch(mergeEngineRepositoryProvider),
    outboundAckDs: ref.watch(syncOutboundAckLocalDsProvider),
  );
}

/// Remote sync transport.
@Riverpod(keepAlive: true)
SyncRemoteDs syncRemoteDs(Ref ref) {
  final ds = SyncRemoteDs(dio: ref.watch(dioClientProvider));
  ref.onDispose(ds.dispose);
  return ds;
}

/// Outbound push ack local data source.
@Riverpod(keepAlive: true)
SyncOutboundAckLocalDs syncOutboundAckLocalDs(Ref ref) {
  return SyncOutboundAckLocalDs(ref.watch(appDatabaseProvider));
}

/// B2C shared-account sync stub.
@Riverpod(keepAlive: true)
SharedAccountSyncClient sharedAccountSyncClient(Ref ref) {
  return const SharedAccountSyncClient();
}

@Riverpod(keepAlive: true)
SyncNowUseCase syncNowUseCase(Ref ref) {
  return SyncNowUseCase(
    syncEngineRepository: ref.watch(syncEngineRepositoryProvider),
    isMultiDeviceSyncUnlocked: ref.watch(isMultiDeviceSyncUnlockedUseCaseProvider),
  );
}

@Riverpod(keepAlive: true)
StartSyncEngineUseCase startSyncEngineUseCase(Ref ref) {
  return StartSyncEngineUseCase(
    syncEngineRepository: ref.watch(syncEngineRepositoryProvider),
    isMultiDeviceSyncUnlocked: ref.watch(isMultiDeviceSyncUnlockedUseCaseProvider),
  );
}

@Riverpod(keepAlive: true)
StopSyncEngineUseCase stopSyncEngineUseCase(Ref ref) {
  return StopSyncEngineUseCase(
    syncEngineRepository: ref.watch(syncEngineRepositoryProvider),
  );
}

@Riverpod(keepAlive: true)
PushPendingOpsUseCase pushPendingOpsUseCase(Ref ref) {
  return PushPendingOpsUseCase(
    syncEngineRepository: ref.watch(syncEngineRepositoryProvider),
    isMultiDeviceSyncUnlocked:
        ref.watch(isMultiDeviceSyncUnlockedUseCaseProvider),
  );
}

@Riverpod(keepAlive: true)
PullAndMergeUseCase pullAndMergeUseCase(Ref ref) {
  return PullAndMergeUseCase(
    syncEngineRepository: ref.watch(syncEngineRepositoryProvider),
    isMultiDeviceSyncUnlocked:
        ref.watch(isMultiDeviceSyncUnlockedUseCaseProvider),
  );
}
