import 'package:daftar/core/constants/app_constants.dart';
import 'package:daftar/domain/constants/entitlement_limits.dart';
import 'package:daftar/presentation/providers/core_providers.dart';
import 'package:daftar/presentation/providers/entitlement_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'workspace_limit_providers.g.dart';

/// Workspace resource tracked for approaching-limit upsells.
enum WorkspaceLimitResource {
  ledgers,
  contacts,
  transactions,
}

/// Snapshot for rendering inline premium upsell banners.
class WorkspaceLimitSnapshot {
  const WorkspaceLimitSnapshot({
    required this.resource,
    required this.currentCount,
    required this.maxCount,
    required this.shouldShowBanner,
  });

  final WorkspaceLimitResource resource;
  final int currentCount;
  final int maxCount;
  final bool shouldShowBanner;
}

@Riverpod(keepAlive: true)
Future<int> totalActiveLedgerCount(Ref ref) async {
  final result = await ref.read(ledgerRepositoryProvider).getActiveCount();
  return result.fold((_) => 0, (count) => count);
}

@Riverpod(keepAlive: true)
Future<int> totalActiveContactCount(Ref ref) async {
  final result = await ref.read(contactRepositoryProvider).getActiveCount();
  return result.fold((_) => 0, (count) => count);
}

@Riverpod(keepAlive: true)
Future<int> totalActiveTransactionCount(Ref ref) async {
  final result = await ref.read(transactionRepositoryProvider).getActiveCount();
  return result.fold((_) => 0, (count) => count);
}

@riverpod
Future<WorkspaceLimitSnapshot> workspaceLimitSnapshot(
  Ref ref,
  WorkspaceLimitResource resource,
) async {
  final entitlement = await ref.watch(entitlementProvider.future);
  final (current, max) = switch (resource) {
    WorkspaceLimitResource.ledgers => (
      await ref.watch(totalActiveLedgerCountProvider.future),
      entitlement.maxLedgers,
    ),
    WorkspaceLimitResource.contacts => (
      await ref.watch(totalActiveContactCountProvider.future),
      entitlement.maxContacts,
    ),
    WorkspaceLimitResource.transactions => (
      await ref.watch(totalActiveTransactionCountProvider.future),
      entitlement.maxTransactions,
    ),
  };

  if (max == EntitlementLimits.unlimited || max <= 0) {
    return WorkspaceLimitSnapshot(
      resource: resource,
      currentCount: current,
      maxCount: max,
      shouldShowBanner: false,
    );
  }

  final threshold = (max * AppConstants.limitWarningThreshold).ceil();
  return WorkspaceLimitSnapshot(
    resource: resource,
    currentCount: current,
    maxCount: max,
    shouldShowBanner: current >= threshold,
  );
}
