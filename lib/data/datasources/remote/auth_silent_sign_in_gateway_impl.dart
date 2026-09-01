import 'package:daftar/data/datasources/remote/google_auth_ds.dart';
import 'package:daftar/domain/services/auth_silent_sign_in_gateway.dart';
import 'package:daftar/domain/value_objects/auth_session_bundle.dart';

/// Data-layer silent recovery adapter backed by the shared [GoogleAuthDs].
///
/// Uses the same `GoogleSignIn.instance` initialization and in-memory account
/// cache as interactive sign-in — never re-initializes the SDK independently.
class AuthSilentSignInGatewayImpl implements AuthSilentSignInGateway {
  const AuthSilentSignInGatewayImpl(this._googleAuthDs);

  final GoogleAuthDs _googleAuthDs;

  @override
  Future<bool> attemptSilentRecovery(AuthSessionBundle bundle) async {
    if (bundle.hasValidCachedAccessToken) {
      return true;
    }

    if (bundle.hasDriveOfflineGrant) {
      final status = await _googleAuthDs.ensureDriveCredential();
      return switch (status) {
        DriveCredentialStatus.ready => true,
        DriveCredentialStatus.revoked => false,
        DriveCredentialStatus.unavailable => true,
      };
    }

    final warmAccount = _googleAuthDs.getAccount();
    if (warmAccount != null && warmAccount.id == bundle.googleUserId) {
      return true;
    }

    final account = await _googleAuthDs.signInSilently();
    return account != null && account.id == bundle.googleUserId;
  }
}
