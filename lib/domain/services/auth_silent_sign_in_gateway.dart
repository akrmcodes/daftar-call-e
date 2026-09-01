import 'package:daftar/domain/value_objects/auth_session_bundle.dart';

/// Recovers a foreground Google Sign-In SDK session from a stored bundle.
///
/// Implemented in the data layer (`AuthSilentSignInGatewayImpl`). Application
/// use cases depend on this contract so Phase 1 bootstrap stays free of
/// Flutter plugin imports.
abstract class AuthSilentSignInGateway {
  /// Initializes the SDK from [bundle] and attempts lightweight authentication.
  ///
  /// Returns `true` when the SDK recovers an account whose Google user id
  /// matches [AuthSessionBundle.googleUserId] and required scopes are authorized.
  /// Returns `false` when recovery is unavailable, cancelled, or identity mismatches.
  Future<bool> attemptSilentRecovery(AuthSessionBundle bundle);
}
