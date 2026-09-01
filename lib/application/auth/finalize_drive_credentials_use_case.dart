import 'package:daftar/core/services/auth_session_store.dart';
import 'package:daftar/domain/enums/auth_session_state.dart';
import 'package:daftar/domain/services/auth_silent_sign_in_gateway.dart';

/// Post-bootstrap Drive credential hydration at app launch.
///
/// When [AuthSessionState.linked] and the secure bundle already holds a valid
/// cached OAuth access token, this is a no-op — Drive I/O can proceed without
/// touching the Google Sign-In SDK.
///
/// When linked but the cached token is missing or expired, performs a single
/// silent SDK recovery attempt at cold start (not deferred to BackupScreen).
class FinalizeDriveCredentialsUseCase {
  const FinalizeDriveCredentialsUseCase(
    this._authSessionStore,
    this._silentSignInGateway,
  );

  final AuthSessionStore _authSessionStore;
  final AuthSilentSignInGateway _silentSignInGateway;

  /// Hydrates Drive credentials globally when bootstrap reports [state].
  Future<void> call(AuthSessionState state) async {
    if (state != AuthSessionState.linked) {
      return;
    }

    final bundle = await _authSessionStore.read();
    if (bundle == null || bundle.hasValidCachedAccessToken) {
      return;
    }

    await _silentSignInGateway.attemptSilentRecovery(bundle);
  }
}
