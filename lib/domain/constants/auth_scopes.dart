/// OAuth scope strings for Google identity and Drive backup.
///
/// Domain-safe constants — no dependency on `googleapis` packages.
abstract final class AuthScopes {
  /// Google Drive `appDataFolder` scope for encrypted cloud backup.
  static const String driveAppData =
      'https://www.googleapis.com/auth/drive.appdata';

  /// OpenID Connect scope — required for Google to return `id_token` on
  /// refresh-token exchange (Closing Agent Cloud Run IAM).
  static const String openId = 'openid';

  /// Email claim on the ID token. Required by Google OIDC together with
  /// [openId] (profile or email must accompany openid).
  static const String email = 'email';

  /// Default scopes granted during the GSI Auth V2 link ceremony.
  ///
  /// Keep this Drive-only so the Sign-In sheet does not change. Cloud Run
  /// ID tokens are minted from the PKCE grant ([pkceOfflineGrantScopes]),
  /// not from GSI `scopeHint`.
  static const List<String> defaultDriveBackupScopes = [driveAppData];

  /// AppAuth PKCE offline-grant scopes: Drive backup + OIDC identity.
  ///
  /// Used only by the Drive PKCE consent (not GSI Sign-In). `openid` is
  /// required for the token endpoint to return `id_token` on refresh.
  static const List<String> pkceOfflineGrantScopes = [
    driveAppData,
    openId,
    email,
  ];

  /// Whether [scopes] include the OpenID Connect scope.
  static bool includesOpenId(Iterable<String> scopes) =>
      scopes.contains(openId);
}
