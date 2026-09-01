/// Extracts opaque deep-link tokens from HTTPS App/Universal Link URIs.
abstract final class DeepLinkTokenParser {
  /// Minimum token length matching DB entropy check (≥32).
  static const int minTokenLength = 32;

  /// Parses `/i/<token>` (or trailing path segment) from [uri].
  ///
  /// Returns `null` when the URI is not a daftar invite link or the token
  /// is too short.
  static String? extractToken(Uri uri) {
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) {
      return null;
    }

    final iIndex = segments.indexOf('i');
    final candidate = iIndex >= 0 && iIndex + 1 < segments.length
        ? segments[iIndex + 1]
        : segments.last;

    final token = candidate.trim();
    if (token.length < minTokenLength) {
      return null;
    }
    return token;
  }

  /// Extracts a token from a raw URL or bare token string.
  static String? extractFromRaw(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    if (!trimmed.contains('://') && trimmed.length >= minTokenLength) {
      return trimmed;
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null) {
      return null;
    }
    return extractToken(uri);
  }
}
