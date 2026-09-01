import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:daftar/data/models/entitlement_payload_model.dart';
import 'package:daftar/domain/entities/entitlement.dart';
import 'package:daftar/domain/enums/app_tier.dart';

/// Encodes and decodes signed entitlement tokens (JWT-like layout).
///
/// Token layouts:
/// - **Server JWT:** standard `header.payload.signature` (stored as-is).
/// - **Offline Daftar v1:** `daftar1.<base64url(payload)>.<base64url(sig)>`.
///
/// Signature verification is a placeholder today; swap [_verifySignature]
/// when the backend publishes its public key.
class EntitlementPayloadCodec {
  static const String _offlinePrefix = 'daftar1';

  /// Builds an offline token for locally validated activations.
  String encodeOffline(Entitlement entitlement) {
    final payload = EntitlementPayloadModel.fromEntitlement(entitlement);
    final payloadSegment = _base64UrlEncode(jsonEncode(payload.toJson()));
    final signature = _placeholderSignature(payloadSegment);
    return '$_offlinePrefix.$payloadSegment.$signature';
  }

  /// Decodes [token] into an [Entitlement], or `null` when corrupt.
  Entitlement? decode(String token) {
    final trimmed = token.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    try {
      if (trimmed.startsWith('$_offlinePrefix.')) {
        return _decodeDaftarToken(trimmed);
      }
      if (trimmed.contains('.')) {
        return _decodeJwtPayload(trimmed);
      }
      return EntitlementPayloadModel.fromJson(
        jsonDecode(trimmed) as Map<String, dynamic>,
      ).toDomain();
    } on Object {
      return null;
    }
  }

  Entitlement? _decodeDaftarToken(String token) {
    final parts = token.split('.');
    if (parts.length != 3) {
      return null;
    }
    final payloadJson = utf8.decode(_base64UrlDecode(parts[1]));
    final payload = EntitlementPayloadModel.fromJson(
      jsonDecode(payloadJson) as Map<String, dynamic>,
    );
    if (!_verifySignature(parts[1], parts[2])) {
      return null;
    }
    return payload.toDomain();
  }

  Entitlement? _decodeJwtPayload(String jwt) {
    final parts = jwt.split('.');
    if (parts.length < 2) {
      return null;
    }
    final payloadJson = utf8.decode(_base64UrlDecode(parts[1]));
    final map = jsonDecode(payloadJson) as Map<String, dynamic>;
    return EntitlementPayloadModel.fromJson(_normalizeJwtClaims(map)).toDomain();
  }

  /// Maps common JWT claim names into our payload schema.
  Map<String, dynamic> _normalizeJwtClaims(Map<String, dynamic> claims) {
    return {
      'v': claims['v'] ?? 1,
      'tier': claims['tier'] ?? claims['plan'] ?? 'free',
      'features': claims['features'] ?? claims['feature_flags'] ?? <String>[],
      'maxLedgers': claims['maxLedgers'] ?? claims['max_ledgers'],
      'maxContacts': claims['maxContacts'] ?? claims['max_contacts'],
      'maxTransactions':
          claims['maxTransactions'] ?? claims['max_transactions'],
      'exp': claims['exp'],
      'iat': claims['iat'],
    };
  }

  bool _verifySignature(String payloadSegment, String signatureSegment) {
    return _placeholderSignature(payloadSegment) == signatureSegment;
  }

  String _placeholderSignature(String payloadSegment) {
    final digest = sha256.convert(utf8.encode('daftar-offline:$payloadSegment'));
    return _base64UrlEncode(digest.bytes);
  }

  String _base64UrlEncode(Object input) {
    final bytes = switch (input) {
      final String s => utf8.encode(s),
      final List<int> b => b,
      _ => utf8.encode(input.toString()),
    };
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  List<int> _base64UrlDecode(String segment) {
    var normalized = segment.replaceAll('-', '+').replaceAll('_', '/');
    final buffer = StringBuffer(normalized);
    while (buffer.length % 4 != 0) {
      buffer.write('=');
    }
    normalized = buffer.toString();
    return base64.decode(normalized);
  }
}

/// Builds default offline entitlement for [tier] (1-year validity).
Entitlement offlineEntitlementForTier(AppTier tier) {
  final expiry = DateTime.now().toUtc().add(const Duration(days: 365));
  return switch (tier) {
    AppTier.pro => Entitlement.forPro(expiryDate: expiry),
    AppTier.proPlus => Entitlement.forProPlus(expiryDate: expiry),
    AppTier.free => Entitlement.defaultFree(),
  };
}
