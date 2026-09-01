/// Auth session timing constants (domain-safe).
abstract final class AuthSessionConstants {
  /// Conservative TTL for cached OAuth access tokens — fallback for legacy
  /// bundles that do not carry a server-reported expiry timestamp.
  static const Duration cachedAccessTokenTtl = Duration(minutes: 55);

  /// Safety margin subtracted from the server-reported token expiry so a
  /// token is never used within the final seconds of its lifetime
  /// (clock skew + multi-minute Drive uploads).
  static const Duration accessTokenExpirySafetyMargin = Duration(minutes: 3);
}
