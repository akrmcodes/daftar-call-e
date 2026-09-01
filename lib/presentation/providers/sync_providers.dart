import 'package:daftar/application/sync/get_sync_status_use_case.dart';
import 'package:daftar/application/sync/get_unresolved_conflicts_use_case.dart';
import 'package:daftar/application/sync/is_multi_device_sync_unlocked_use_case.dart';
import 'package:daftar/application/sync/merge_remote_ops_use_case.dart';
import 'package:daftar/domain/entities/merge_conflict.dart';
import 'package:daftar/domain/entities/sync_status.dart';
import 'package:daftar/domain/enums/sync_result_type.dart';
import 'package:daftar/presentation/providers/core_providers.dart';
import 'package:daftar/presentation/providers/sync_auth_bridge_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'sync_providers.g.dart';

// ══════════════════════════════════════════════════════════════════════════
// USE CASE PROVIDERS
// ══════════════════════════════════════════════════════════════════════════

/// Pro+ multi-device sync entitlement check.
@Riverpod(keepAlive: true)
IsMultiDeviceSyncUnlockedUseCase isMultiDeviceSyncUnlockedUseCase(Ref ref) {
  return IsMultiDeviceSyncUnlockedUseCase(
    activationRepository: ref.watch(activationRepositoryProvider),
    syncAuthBridgeRepository: ref.watch(syncAuthBridgeRepositoryProvider),
  );
}

/// Whether sync is unlocked via local Pro+ or an active worker JWT.
@riverpod
Future<bool> isMultiDeviceSyncUnlocked(Ref ref) async {
  return ref.read(isMultiDeviceSyncUnlockedUseCaseProvider).call();
}

/// Provides the merge remote ops use case (Pro+ gated).
@Riverpod(keepAlive: true)
MergeRemoteOpsUseCase mergeRemoteOpsUseCase(Ref ref) {
  return MergeRemoteOpsUseCase(
    mergeEngineRepository: ref.watch(mergeEngineRepositoryProvider),
    isMultiDeviceSyncUnlocked: ref.watch(isMultiDeviceSyncUnlockedUseCaseProvider),
  );
}

/// Provides the get sync status use case.
@Riverpod(keepAlive: true)
GetSyncStatusUseCase getSyncStatusUseCase(Ref ref) {
  return GetSyncStatusUseCase(
    mergeEngineRepository: ref.watch(mergeEngineRepositoryProvider),
  );
}

/// Provides the get unresolved conflicts use case.
@Riverpod(keepAlive: true)
GetUnresolvedConflictsUseCase getUnresolvedConflictsUseCase(Ref ref) {
  return GetUnresolvedConflictsUseCase(
    mergeEngineRepository: ref.watch(mergeEngineRepositoryProvider),
  );
}

// ══════════════════════════════════════════════════════════════════════════
// PRESENTATION STATE PROVIDERS
// ══════════════════════════════════════════════════════════════════════════

/// Current sync status — last sync, pending ops, conflicts.
///
/// For non-Pro+ users, returns a dormant [SyncStatus].
@riverpod
Future<SyncStatus> syncStatus(Ref ref) async {
  final isEntitled =
      await ref.watch(isMultiDeviceSyncUnlockedUseCaseProvider).call();

  if (!isEntitled) {
    return const SyncStatus();
  }

  final useCase = ref.watch(getSyncStatusUseCaseProvider);
  final result = await useCase();

  return result.fold(
    (_) => const SyncStatus(lastSyncResult: SyncResultType.failed),
    (status) => status,
  );
}

/// Unresolved merge conflicts for the Sync Report screen.
@riverpod
Future<List<MergeConflict>> unresolvedConflicts(Ref ref) async {
  final isEntitled =
      await ref.watch(isMultiDeviceSyncUnlockedUseCaseProvider).call();

  if (!isEntitled) {
    return const [];
  }

  final useCase = ref.watch(getUnresolvedConflictsUseCaseProvider);
  final result = await useCase();

  return result.fold(
    (_) => const [],
    (conflicts) => conflicts,
  );
}
