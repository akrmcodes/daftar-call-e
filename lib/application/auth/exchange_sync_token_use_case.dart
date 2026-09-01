import 'package:daftar/core/constants/app_constants.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/repositories/sync_auth_bridge_repository.dart';
import 'package:fpdart/fpdart.dart';

/// Exchanges a Google ID token for a custom Supabase sync JWT (Stage 8.2).
///
/// Delegates to [SyncAuthBridgeRepository] — never imports data-layer clients.
/// Returns [AuthFailure] when the Google session cannot produce an ID token or
/// when the Edge Function rejects verification.
///
/// Contest quarantine: when [AppConstants.kContestDisableMultiDeviceSync] is
/// true, never calls the Auth Bridge (Stage 8 disabled).
class ExchangeSyncTokenUseCase {
  /// Creates the exchange use case.
  const ExchangeSyncTokenUseCase(this._syncAuthBridge);

  final SyncAuthBridgeRepository _syncAuthBridge;

  static const AuthFailure _contestQuarantined = AuthFailure(
    'Multi-device sync is disabled for this contest build.',
    code: 'contest_sync_quarantined',
  );

  /// Returns a valid cached sync token when present; otherwise exchanges.
  Future<Either<Failure, SyncAuthCredentials>> ensureValid({
    bool allowInteractive = false,
  }) {
    // Contest quarantine — Stage 8 disabled.
    if (AppConstants.kContestDisableMultiDeviceSync) {
      return Future.value(const Left(_contestQuarantined));
    }
    return _syncAuthBridge.ensureValid(allowInteractive: allowInteractive);
  }

  /// Forces a fresh Google ID token exchange via the Auth Bridge.
  Future<Either<Failure, SyncAuthCredentials>> exchange({
    bool allowInteractive = false,
  }) {
    // Contest quarantine — Stage 8 disabled.
    if (AppConstants.kContestDisableMultiDeviceSync) {
      return Future.value(const Left(_contestQuarantined));
    }
    return _syncAuthBridge.exchange(allowInteractive: allowInteractive);
  }
}
