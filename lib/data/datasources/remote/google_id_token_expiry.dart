import 'dart:convert';

/// Decodes JWT `exp` without verifying the signature.
///
/// Cloud Run still verifies the token. Local expiry is only used to avoid
/// sending a stale Bearer token after hot restart.
DateTime? googleIdTokenExpiry(String idToken) {
  final exp = _payload(idToken)?['exp'];
  if (exp is! num) {
    return null;
  }
  return DateTime.fromMillisecondsSinceEpoch(
    exp.round() * 1000,
    isUtc: true,
  );
}

/// Decodes JWT `sub` without verifying the signature.
///
/// Used to fail-closed when a PKCE-minted ID token is for a different
/// Google user than the linked session `googleUserId`.
String? googleIdTokenSubject(String idToken) {
  final sub = _payload(idToken)?['sub'];
  if (sub is! String) {
    return null;
  }
  final trimmed = sub.trim();
  return trimmed.isEmpty ? null : trimmed;
}

Map<dynamic, dynamic>? _payload(String idToken) {
  final parts = idToken.split('.');
  if (parts.length < 2) {
    return null;
  }
  try {
    final normalized = base64Url.normalize(parts[1]);
    final payload = jsonDecode(utf8.decode(base64Url.decode(normalized)));
    return payload is Map ? payload : null;
  } on Object {
    return null;
  }
}
