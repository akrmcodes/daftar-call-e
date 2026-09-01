import 'dart:async';

import 'package:daftar/core/constants/app_constants.dart';
import 'package:daftar/domain/entities/entitlement.dart';
import 'package:daftar/domain/enums/feature_flag.dart';
import 'package:daftar/presentation/providers/core_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'entitlement_providers.g.dart';

/// Single source of truth for the active [Entitlement] (tier, limits, flags).
@Riverpod(keepAlive: true)
Future<Entitlement> entitlement(Ref ref) async {
  return ref.watch(activationRepositoryProvider).getEntitlement();
}

/// Whether another contact can be added given [currentCount] live contacts.
@riverpod
Future<bool> canAddContact(Ref ref, int currentCount) async {
  final e = await ref.watch(entitlementProvider.future);
  return e.canAddContact(currentCount);
}

/// Whether another ledger can be created given [currentCount] live ledgers.
@riverpod
Future<bool> canAddLedger(Ref ref, int currentCount) async {
  final e = await ref.watch(entitlementProvider.future);
  return e.canAddLedger(currentCount);
}

/// Whether another transaction can be added given [currentCount] live txns.
@riverpod
Future<bool> canAddTransaction(Ref ref, int currentCount) async {
  final e = await ref.watch(entitlementProvider.future);
  return e.canAddTransaction(currentCount);
}

/// Whether [feature] is unlocked for the current entitlement.
///
/// Contest quarantine: [FeatureFlag.multiDeviceSync] is always false when
/// [AppConstants.kContestDisableMultiDeviceSync] is on.
@riverpod
Future<bool> canUseFeature(Ref ref, FeatureFlag feature) async {
  // Contest quarantine — Stage 8 disabled.
  if (AppConstants.kContestDisableMultiDeviceSync &&
      feature == FeatureFlag.multiDeviceSync) {
    return false;
  }
  final e = await ref.watch(entitlementProvider.future);
  return e.hasFeature(feature);
}

/// Invalidates entitlement after a successful code activation.
@Riverpod(keepAlive: true)
class EntitlementController extends _$EntitlementController {
  @override
  FutureOr<void> build() {}

  Future<void> refreshAfterActivation() async {
    ref.invalidate(entitlementProvider);
  }
}
