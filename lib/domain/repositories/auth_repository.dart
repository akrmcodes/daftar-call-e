import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/entities/google_account_profile.dart';
import 'package:daftar/domain/enums/auth_session_state.dart';
import 'package:fpdart/fpdart.dart';

/// Machine-readable code: the interactive PKCE consent did not produce a
/// Drive refresh token (browser dismissed, console misconfiguration, or
/// Google declined the offline grant).
const String kDriveOfflineGrantFailedCode = 'drive_offline_grant_failed';

/// Machine-readable code: the PKCE grant can backup Drive but cannot mint
/// a Google ID token until the merchant re-consents with `openid`.
const String kAgentOpenIdGrantRequiredCode = 'agent_openid_grant_required';

/// Contract for Google-based authentication operations (Auth V2).
///
/// Pure domain interface — Google Sign-In SDK usage lives in the data layer.
/// Signed-in state is determined from the secure session bundle, not Drift.
abstract class AuthRepository {
  /// Starts the interactive Google sign-in flow.
  ///
  /// On success the implementation must persist the session bundle before
  /// updating denormalized Drift identity fields.
  Future<Either<Failure, Unit>> signInWithGoogle();

  /// Attempts lightweight / silent re-authentication for returning users.
  Future<Either<Failure, Unit>> signInSilently();

  /// Signs the current user out of Google.
  ///
  /// On success the implementation must delete the session bundle before
  /// clearing Drift Google fields.
  Future<Either<Failure, Unit>> signOut();

  /// Returns the signed-in Google account id from the secure bundle.
  ///
  /// Returns `null` when no bundle is present. Never reads Drift.
  Future<Either<Failure, String?>> getSignedInAccount();

  /// Returns whether a secure session bundle exists.
  ///
  /// Reads the bundle only — Drift `googleAccountId` is not consulted.
  Future<bool> isSignedIn();

  /// Returns profile fields for the active Google session, or null when signed out.
  Future<Either<Failure, GoogleAccountProfile?>> getGoogleAccountProfile();

  /// Resolves cold-start session state via session bootstrap (Phase 1.3).
  Future<AuthSessionState> getSessionState();

  /// Resolves session state immediately after interactive sign-in while the SDK
  /// session is still warm — avoids redundant cold-start bootstrap.
  Future<AuthSessionState> getSessionStateAfterInteractiveSignIn();

  /// Whether the secure bundle holds a Drive offline grant (refresh token) —
  /// the credential that keeps headless backup alive indefinitely.
  Future<bool> hasDriveOfflineGrant();

  /// Interactively re-runs the PKCE consent to mint the Drive offline grant
  /// (and `openid` for Closing Agent ID-token refresh) for an already-linked
  /// session. Foreground-only. Skips when the stored PKCE grant already
  /// includes `openid`.
  Future<Either<Failure, Unit>> completeDriveAuthorization();

  /// Returns a Google ID token for the linked session without a second picker.
  ///
  /// When [allowLightweightRestore] is true (user-initiated agent Send only),
  /// hydrates via the PKCE refresh token. GSI One Tap / `authenticate()` is
  /// never used. An ID token whose `sub` ≠ the bundle `googleUserId` is
  /// fail-closed.
  Future<Either<Failure, String>> ensureLinkedIdToken({
    bool allowLightweightRestore = false,
  });
}
