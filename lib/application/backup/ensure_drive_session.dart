import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/utils/cloud_sync_failure.dart';
import 'package:daftar/domain/repositories/auth_repository.dart';
import 'package:daftar/domain/services/drive_session_gateway.dart';
import 'package:fpdart/fpdart.dart';

export 'package:daftar/domain/services/drive_session_gateway.dart'
    show kDriveScopesNotAuthorizedCode;

/// Restores a Google Drive session without interactive sign-in when possible.
///
/// Call before any Drive upload, list, or download. Avoids the false negative
/// where [AuthRepository.isSignedIn] is false on cold start even though the
/// user previously linked Google.
Future<Either<Failure, Unit>> ensureDriveSession(AuthRepository authRepository) {
  return authRepository.signInSilently();
}

/// Headless-safe Drive session hydration for Workmanager and background isolates.
///
/// Unlike [ensureDriveSession] alone, this verifies that `drive.appdata` scopes
/// are authorized via `authorizationForScopes` only (never `authorizeScopes`)
/// and that an HTTP client can be obtained without UI.
///
/// ## 4-Step Verification Pipeline
///
/// Each step produces a distinct failure code for observability:
///
/// 1. **signInSilently** → `silent_sign_in_failed` / `AuthFailure.notSignedIn`
///    Restores the Google SDK session from the native credential store.
///
/// 2. **getAccount** → `silent_sign_in_failed`
///    Verifies the Google Sign-In SDK cached account was populated by step 1.
///
/// 3. **hasDriveScopesAuthorized** → [kDriveScopesNotAuthorizedCode]
///    Checks `authorizationForScopes` without prompting. If scopes were
///    revoked server-side, this step fails.
///
/// 4. **getAuthenticatedHttpClient(headless: true)** → `google_not_signed_in`
///    / `drive_auth_client_failed`
///    Obtains a Bearer-token-equipped HTTP client for Drive API calls.
///    Runs in headless mode — no interactive fallback.
Future<Either<Failure, Unit>> ensureHeadlessDriveSession({
  required AuthRepository authRepository,
  required DriveSessionGateway driveSessionGateway,
}) async {
  return driveSessionGateway.verifyHeadlessDrivePrerequisitesPkceOnly();
}

/// Machine-readable code: the PKCE refresh token was revoked server-side.
///
/// Mirrors `GoogleAuthFailureMapper.kDriveRefreshTokenRevokedCode` without a
/// data-layer import (application layer must stay free of `lib/data/`).
const String kDriveRefreshTokenRevokedFailureCode =
    'drive_refresh_token_revoked';

/// Whether [failure] proves the offline grant is permanently dead.
///
/// `invalid_grant` from Google's token endpoint is a definitive server-side
/// verdict — unlike SDK cold-start ambiguity, it is safe to record
/// `needs_reauth` from a headless isolate on this signal.
bool isDriveGrantRevokedFailure(Failure failure) {
  return failure is AuthFailure &&
      failure.code == kDriveRefreshTokenRevokedFailureCode;
}

/// Whether [failure] requires interactive re-link (sticky `needs_reauth`).
///
/// Transient network / PKCE-unavailable failures must NEVER set sticky reauth
/// — they recover when connectivity returns or the next chain tick refreshes.
bool isStickyNeedsReauthFailure(Failure failure) {
  if (failure is! AuthFailure) {
    return false;
  }
  final code = failure.code;
  return code == kDriveRefreshTokenRevokedFailureCode ||
      code == kDriveScopesNotAuthorizedCode ||
      code == 'drive_unauthorized' ||
      code == 'drive_forbidden' ||
      code == 'canceled';
}

/// Whether [failure] is a transient fault that should use chain backoff
/// (not sticky reauth, not a permanent skip).
bool isTransientBackgroundDriveFailure(Failure failure) {
  if (failure is NetworkFailure || isTransientCloudSyncFailure(failure)) {
    return true;
  }
  if (failure is! AuthFailure) {
    return false;
  }
  final code = failure.code;
  // Soft headless/SDK ambiguity — retry later via chain, do not sticky-logout.
  return code == 'silent_sign_in_failed' ||
      code == 'drive_auth_client_failed' ||
      code == 'google_not_signed_in';
}

/// @Deprecated Prefer [isStickyNeedsReauthFailure] / [isTransientBackgroundDriveFailure].
/// Kept for call sites that still gate "no OS Result.retry" semantics.
bool isTerminalBackgroundDriveAuthFailure(Failure failure) {
  return isStickyNeedsReauthFailure(failure) ||
      (failure is AuthFailure &&
          (failure.code == 'google_not_signed_in' ||
              failure.code == 'silent_sign_in_failed' ||
              failure.code == 'drive_auth_client_failed'));
}
