/// Builds Google Play Store URLs with Install Referrer payloads (Stage 8.5).
abstract final class PlayStoreReferrerBuilder {
  /// Play package id for Daftar.
  static const playPackageId = 'com.akrmcodes.daftar';

  /// Base Play Store listing URL (no referrer).
  static const playStoreListingBase =
      'https://play.google.com/store/apps/details?id=$playPackageId';

  /// Encodes [token] into the `referrer` query param for Play Install Referrer.
  ///
  /// Decoded form: `utm_source=daftar&utm_medium=deep_link&utm_content={token}`
  static String buildReferrerParam(String token) {
    final raw =
        'utm_source=daftar&utm_medium=deep_link&utm_content=$token';
    return Uri.encodeComponent(raw);
  }

  /// Full Play Store URL with Install Referrer for deferred deep links.
  static String buildPlayStoreUrlWithToken(String token) {
    final referrer = buildReferrerParam(token);
    return '$playStoreListingBase&referrer=$referrer';
  }
}
