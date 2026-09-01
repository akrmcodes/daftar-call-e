import 'package:daftar/domain/constants/auth_scopes.dart';
import 'package:daftar/domain/constants/auth_session_constants.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_session_bundle.freezed.dart';

/// Authoritative Google identity session record for Auth V2.
///
/// Persisted exclusively via secure storage (`AuthSessionStore`, Phase 1.2).
/// Drift `googleAccountId` / `googleAccountEmail` are denormalized UI hints
/// only — this bundle is the single source of truth for signed-in state.
///
/// ## Persistence contract (HARD RULE)
///
/// - Interactive sign-in MUST write the bundle **before** updating Drift.
/// - Sign-out MUST delete the bundle **before** clearing Drift Google fields.
/// - Background isolates may read the bundle; they must not rewrite it except
///   for updating `lastSuccessfulSilentAuthAt`.
///
/// ## Field semantics
///
/// - `googleUserId`: Stable Google account identifier (`sub` / account id).
/// - `email`: Primary Google account email at link time.
/// - `serverClientId`: Web OAuth client id used when the session was linked.
/// - `scopesGranted`: OAuth scopes authorized at link time (e.g. drive.appdata).
/// - `linkedAt`: UTC timestamp of the initial interactive link ceremony.
/// - `lastSuccessfulSilentAuthAt`: UTC timestamp of the last successful
///   lightweight/silent auth (null until first silent recovery).
/// - `cachedIdToken` / `cachedIdTokenExpiresAt`: Google ID token for Cloud Run
///   (Closing Agent) and Stage 8 sync. Optional; absent on schema v1–v4.
///
/// ## Non-goals (HARD RULE — Auth V2 Phase 1.4)
///
/// - NEVER store OAuth tokens in `SharedPreferences` — secure storage only.
/// - NEVER treat Drift `googleAccountId` alone as proof of signed-in state.
/// - NEVER swallow silent auth failures on cold start — emit `needsReauth`.
@freezed
abstract class AuthSessionBundle with _$AuthSessionBundle {
  const factory AuthSessionBundle({
    required String googleUserId,
    required String email,
    required String serverClientId,
    required List<String> scopesGranted,
    required DateTime linkedAt,
    String? displayName,
    String? photoUrl,
    DateTime? lastSuccessfulSilentAuthAt,
    String? cachedAccessToken,
    DateTime? cachedAccessTokenObtainedAt,
    DateTime? cachedAccessTokenExpiresAt,
    String? driveRefreshToken,
    String? driveTokenClientId,
    String? cachedIdToken,
    DateTime? cachedIdTokenExpiresAt,
  }) = _AuthSessionBundle;

  /// Creates a validated [AuthSessionBundle] at auth/persistence boundaries.
  ///
  /// Trims strings, normalizes timestamps to UTC, and rejects invalid input.
  factory AuthSessionBundle.create({
    required String googleUserId,
    required String email,
    required String serverClientId,
    required List<String> scopesGranted,
    required DateTime linkedAt,
    String? displayName,
    String? photoUrl,
    DateTime? lastSuccessfulSilentAuthAt,
    String? cachedAccessToken,
    DateTime? cachedAccessTokenObtainedAt,
    DateTime? cachedAccessTokenExpiresAt,
    String? driveRefreshToken,
    String? driveTokenClientId,
    String? cachedIdToken,
    DateTime? cachedIdTokenExpiresAt,
  }) {
    final normalizedUserId = googleUserId.trim();
    if (normalizedUserId.isEmpty) {
      throw ArgumentError.value(
        googleUserId,
        'googleUserId',
        'must not be empty',
      );
    }

    final normalizedEmail = email.trim();
    if (normalizedEmail.isEmpty || !normalizedEmail.contains('@')) {
      throw ArgumentError.value(email, 'email', 'must be a non-empty email');
    }

    final normalizedServerClientId = serverClientId.trim();
    if (normalizedServerClientId.isEmpty) {
      throw ArgumentError.value(
        serverClientId,
        'serverClientId',
        'must not be empty',
      );
    }

    final normalizedScopes = scopesGranted
        .map((scope) => scope.trim())
        .where((scope) => scope.isNotEmpty)
        .toList(growable: false);
    if (normalizedScopes.isEmpty) {
      throw ArgumentError.value(
        scopesGranted,
        'scopesGranted',
        'must contain at least one scope',
      );
    }

    return AuthSessionBundle(
      googleUserId: normalizedUserId,
      email: normalizedEmail,
      serverClientId: normalizedServerClientId,
      scopesGranted: List.unmodifiable(normalizedScopes),
      linkedAt: linkedAt.toUtc(),
      displayName: _nullableTrimmed(displayName),
      photoUrl: _nullableTrimmed(photoUrl),
      lastSuccessfulSilentAuthAt: lastSuccessfulSilentAuthAt?.toUtc(),
      cachedAccessToken: _nullableTrimmed(cachedAccessToken),
      cachedAccessTokenObtainedAt: cachedAccessTokenObtainedAt?.toUtc(),
      cachedAccessTokenExpiresAt: cachedAccessTokenExpiresAt?.toUtc(),
      driveRefreshToken: _nullableTrimmed(driveRefreshToken),
      driveTokenClientId: _nullableTrimmed(driveTokenClientId),
      cachedIdToken: _nullableTrimmed(cachedIdToken),
      cachedIdTokenExpiresAt: cachedIdTokenExpiresAt?.toUtc(),
    );
  }

  const AuthSessionBundle._();

  /// Whether `scopesGranted` includes Drive `appDataFolder` access.
  bool get hasDriveAppDataScope =>
      scopesGranted.contains(AuthScopes.driveAppData);

  /// Returns a copy with `lastSuccessfulSilentAuthAt` set to UTC [timestamp].
  AuthSessionBundle withSilentAuthTimestamp(DateTime timestamp) => copyWith(
        lastSuccessfulSilentAuthAt: timestamp.toUtc(),
      );

  /// Whether a cached Drive access token is present and not expired.
  ///
  /// Prefers the server-reported expiry ([cachedAccessTokenExpiresAt], with a
  /// safety margin) and falls back to the conservative
  /// [AuthSessionConstants.cachedAccessTokenTtl] window for legacy bundles
  /// that only carry `cachedAccessTokenObtainedAt`.
  bool get hasValidCachedAccessToken {
    final token = cachedAccessToken;
    if (token == null || token.isEmpty) {
      return false;
    }
    final now = DateTime.now().toUtc();
    final expiresAt = cachedAccessTokenExpiresAt;
    if (expiresAt != null) {
      return now.isBefore(
        expiresAt.subtract(AuthSessionConstants.accessTokenExpirySafetyMargin),
      );
    }
    final obtainedAt = cachedAccessTokenObtainedAt;
    if (obtainedAt == null) {
      return false;
    }
    return now.difference(obtainedAt) <
        AuthSessionConstants.cachedAccessTokenTtl;
  }

  /// Returns a copy with a freshly obtained OAuth access token.
  ///
  /// [expiresAt] is the server-reported expiry when known (token endpoint
  /// `expires_in`, AppAuth response, or tokeninfo introspection).
  AuthSessionBundle withCachedAccessToken(
    String accessToken, {
    DateTime? expiresAt,
  }) =>
      copyWith(
        cachedAccessToken: accessToken,
        cachedAccessTokenObtainedAt: DateTime.now().toUtc(),
        cachedAccessTokenExpiresAt: expiresAt?.toUtc(),
      );

  /// Returns a copy with the cached access token dropped (e.g. after a Drive
  /// 401 proves the token is dead despite a future expiry timestamp).
  AuthSessionBundle withoutCachedAccessToken() => copyWith(
        cachedAccessToken: null,
        cachedAccessTokenObtainedAt: null,
        cachedAccessTokenExpiresAt: null,
      );

  /// Whether a PKCE offline grant (refresh token) is stored for headless use.
  bool get hasDriveOfflineGrant =>
      driveRefreshToken != null &&
      driveRefreshToken!.isNotEmpty &&
      driveTokenClientId != null &&
      driveTokenClientId!.isNotEmpty;

  /// Whether the stored PKCE grant can silently mint a Google ID token.
  ///
  /// Requires both a refresh token and `openid` in [scopesGranted]. Legacy
  /// Drive-only grants return false until the merchant re-consents.
  bool get hasOpenIdOfflineGrant =>
      hasDriveOfflineGrant && AuthScopes.includesOpenId(scopesGranted);

  /// Returns a copy carrying the PKCE offline grant issued at link time.
  ///
  /// When [scopesGranted] is set (PKCE consent), it replaces the stored
  /// scope list so [hasOpenIdOfflineGrant] tracks the live grant.
  AuthSessionBundle withDriveOfflineGrant({
    required String refreshToken,
    required String clientId,
    List<String>? scopesGranted,
  }) {
    final normalizedScopes = scopesGranted
        ?.map((scope) => scope.trim())
        .where((scope) => scope.isNotEmpty)
        .toList(growable: false);
    return copyWith(
      driveRefreshToken: refreshToken,
      driveTokenClientId: clientId,
      scopesGranted: normalizedScopes == null || normalizedScopes.isEmpty
          ? this.scopesGranted
          : List.unmodifiable(normalizedScopes),
    );
  }

  /// Whether a cached Google ID token is present and not expired.
  ///
  /// Requires [cachedIdTokenExpiresAt] (JWT `exp` or a conservative fallback).
  /// Tokens inside [AuthSessionConstants.accessTokenExpirySafetyMargin] of
  /// expiry are treated as dead.
  bool get hasValidCachedIdToken {
    final token = cachedIdToken;
    if (token == null || token.isEmpty) {
      return false;
    }
    final expiresAt = cachedIdTokenExpiresAt;
    if (expiresAt == null) {
      return false;
    }
    return DateTime.now().toUtc().isBefore(
      expiresAt.subtract(AuthSessionConstants.accessTokenExpirySafetyMargin),
    );
  }

  /// Returns a copy with a freshly obtained Google ID token.
  AuthSessionBundle withCachedIdToken(
    String idToken, {
    DateTime? expiresAt,
  }) =>
      copyWith(
        cachedIdToken: idToken,
        cachedIdTokenExpiresAt: expiresAt?.toUtc(),
      );
}

String? _nullableTrimmed(String? value) {
  if (value == null) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
