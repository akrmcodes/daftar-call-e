/// Thrown when an authenticated HTTP client is requested but no Google
/// account is signed in or Drive scopes are not authorized.
class GoogleAuthNotSignedInException implements Exception {
  /// Creates a [GoogleAuthNotSignedInException].
  const GoogleAuthNotSignedInException([
    this.message = 'Not signed in with Google.',
  ]);

  /// Human-readable explanation.
  final String message;

  @override
  String toString() => message;
}

/// Thrown when Google OAuth env configuration is missing or invalid.
class GoogleAuthConfigurationException implements Exception {
  /// Creates a [GoogleAuthConfigurationException].
  const GoogleAuthConfigurationException(this.message);

  /// Explanation for developers and logs.
  final String message;

  @override
  String toString() => message;
}

/// Thrown when Google's token endpoint answers `invalid_grant` for the stored
/// refresh token — the offline grant was revoked (user action, password change
/// with Gmail scopes, 6-month inactivity, or Testing-mode consent screen).
///
/// This is a cryptographic fact, not an SDK cold-start ambiguity — safe to
/// surface as a genuine re-auth requirement even from headless isolates.
class GoogleDriveGrantRevokedException implements Exception {
  /// Creates a [GoogleDriveGrantRevokedException].
  const GoogleDriveGrantRevokedException([
    this.message = 'Google Drive offline access was revoked. Sign in again.',
  ]);

  /// Human-readable explanation.
  final String message;

  @override
  String toString() => message;
}

/// Thrown when the AppAuth PKCE consent flow fails on the platform channel.
class GoogleAuthAppAuthException implements Exception {
  const GoogleAuthAppAuthException({
    required this.message,
    required this.code,
  });

  final String message;
  final String code;

  @override
  String toString() => message;
}

/// Thrown when an interactive Google Sign-In or authorization step exceeds its
/// bounded timeout.
///
/// Guards against the Android `authorizeScopes` consent screen hanging
/// indefinitely (flutter/flutter#86785) by converting a stuck platform channel
/// into a recoverable `AuthFailure` instead of a permanent UI spinner.
class GoogleAuthTimeoutException implements Exception {
  /// Creates a [GoogleAuthTimeoutException].
  const GoogleAuthTimeoutException([
    this.message = 'Google sign-in timed out before completing.',
  ]);

  /// Human-readable explanation.
  final String message;

  @override
  String toString() => message;
}
