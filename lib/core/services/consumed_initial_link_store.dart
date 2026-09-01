import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Tracks the last cold-start `getInitialLink()` URI/token consumed on device.
///
/// Prevents sticky Android launcher intents from reopening invite accept/ceremony
/// on every cold start after the user has already seen that initial link once.
class ConsumedInitialLinkStore {
  /// Creates the store.
  ConsumedInitialLinkStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _consumedInitialLinkKey = 'daftar_consumed_initial_link';

  final FlutterSecureStorage _storage;

  /// Returns true when [uri] or [token] matches the last consumed initial link.
  Future<bool> isConsumed({Uri? uri, String? token}) async {
    final entry = await _readEntry();
    if (entry == null) {
      return false;
    }
    if (uri != null && entry.uri == uri.toString()) {
      return true;
    }
    final normalizedToken = token?.trim();
    if (normalizedToken != null &&
        normalizedToken.isNotEmpty &&
        entry.token == normalizedToken) {
      return true;
    }
    return false;
  }

  /// Persists [uri] and optional [token] as the consumed cold-start link.
  Future<void> markConsumed({required Uri uri, String? token}) async {
    final normalizedToken = token?.trim();
    await _storage.write(
      key: _consumedInitialLinkKey,
      value: jsonEncode({
        'uri': uri.toString(),
        if (normalizedToken != null && normalizedToken.isNotEmpty)
          'token': normalizedToken,
      }),
    );
  }

  Future<_ConsumedInitialLinkEntry?> _readEntry() async {
    try {
      final raw = await _storage.read(key: _consumedInitialLinkKey);
      if (raw == null || raw.isEmpty) {
        return null;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      final uri = decoded['uri'];
      if (uri is! String || uri.isEmpty) {
        return null;
      }
      final token = decoded['token'];
      return _ConsumedInitialLinkEntry(
        uri: uri,
        token: token is String ? token.trim() : null,
      );
    } on Object catch (error, stackTrace) {
      debugPrint('ConsumedInitialLinkStore read failed: $error\n$stackTrace');
      return null;
    }
  }
}

class _ConsumedInitialLinkEntry {
  const _ConsumedInitialLinkEntry({
    required this.uri,
    this.token,
  });

  final String uri;
  final String? token;
}
