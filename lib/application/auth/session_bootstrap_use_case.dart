import 'dart:async';

import 'package:daftar/application/auth/reconcile_drift_identity_use_case.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/services/auth_session_store.dart';
import 'package:daftar/domain/enums/auth_session_state.dart';
import 'package:daftar/domain/repositories/settings_repository.dart';
import 'package:daftar/domain/services/auth_silent_sign_in_gateway.dart';
import 'package:daftar/domain/value_objects/auth_session_bundle.dart';
import 'package:fpdart/fpdart.dart';

/// Resolves Auth V2 session state on cold start.
///
/// Implements the bootstrap state machine in `docs/product/roadmap.md` (Stage 4.5 — Auth V2).
///
/// ## State resolution
/// - Bundle absent + Drift `googleAccountId` present → [AuthSessionState.migrationRelinkRequired]
/// - Bundle absent + Drift empty → [AuthSessionState.unlinked]
/// - Bundle present + silent recovery succeeds → [AuthSessionState.linked] (after Drift reconcile)
/// - Bundle present + silent recovery fails → [AuthSessionState.needsReauth]
///
/// ## Non-goals (HARD RULE — Auth V2 Phase 1.4)
///
/// - NEVER store OAuth tokens in `SharedPreferences` — secure storage only.
/// - NEVER treat Drift `googleAccountId` alone as proof of signed-in state.
/// - NEVER swallow silent auth failures on cold start — emit
///   [AuthSessionState.needsReauth] (see [_attemptSilentRecovery]).
class SessionBootstrapUseCase {
  const SessionBootstrapUseCase(
    this._authSessionStore,
    this._settingsRepository,
    this._silentSignInGateway,
    this._reconcileDriftIdentityUseCase,
  );

  static const Duration _bootstrapSilentRecoveryTimeout = Duration(seconds: 5);

  final AuthSessionStore _authSessionStore;
  final SettingsRepository _settingsRepository;
  final AuthSilentSignInGateway _silentSignInGateway;
  final ReconcileDriftIdentityUseCase _reconcileDriftIdentityUseCase;

  /// Runs the cold-start bootstrap protocol.
  Future<Either<Failure, AuthSessionState>> execute() async {
    final bundle = await _authSessionStore.read();
    final settingsResult = await _settingsRepository.get();
    if (settingsResult case Left(value: final failure)) {
      return Left(failure);
    }

    final driftGoogleAccountId =
        settingsResult.getRight().toNullable()!.googleAccountId;
    final hasDriftGhostId = _hasGoogleAccountId(driftGoogleAccountId);

    if (bundle == null) {
      if (hasDriftGhostId) {
        return const Right(AuthSessionState.migrationRelinkRequired);
      }
      return const Right(AuthSessionState.unlinked);
    }

    return _resolveBundlePresent(bundle);
  }

  Future<Either<Failure, AuthSessionState>> _resolveBundlePresent(
    AuthSessionBundle bundle,
  ) async {
    final credentialsAvailable = bundle.hasValidCachedAccessToken ||
        await _attemptSilentRecovery(bundle);
    if (!credentialsAvailable) {
      return const Right(AuthSessionState.needsReauth);
    }

    if (!bundle.hasValidCachedAccessToken) {
      await _authSessionStore.updateLastSuccessfulSilentAuthAt(
        DateTime.now().toUtc(),
      );
    }

    final reconcileResult = await _reconcileDriftIdentityUseCase.execute(bundle);
    if (reconcileResult case Left(value: final failure)) {
      return Left(failure);
    }

    return const Right(AuthSessionState.linked);
  }

  Future<bool> _attemptSilentRecovery(AuthSessionBundle bundle) async {
    try {
      if (bundle.hasDriveOfflineGrant) {
        return await _silentSignInGateway.attemptSilentRecovery(bundle);
      }
      return await _silentSignInGateway
          .attemptSilentRecovery(bundle)
          .timeout(_bootstrapSilentRecoveryTimeout, onTimeout: () => false);
    } on Object {
      return false;
    }
  }

  bool _hasGoogleAccountId(String? googleAccountId) =>
      googleAccountId != null && googleAccountId.trim().isNotEmpty;
}
