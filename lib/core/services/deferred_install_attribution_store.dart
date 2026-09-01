import 'package:daftar/core/utils/deep_link_token_parser.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Deferred-install token capture (Stage 8.5).
///
/// Android: Play Install Referrer is read when the `play_install_referrer`
/// package is wired; until then [captureFromReferrerString] accepts a raw
/// referrer for tests / future integration.
///
/// iOS: clipboard probe is handled in the ceremony UI; this store only
/// persists a one-shot pending token so cold-start claim is idempotent.
class DeferredInstallAttributionStore {
  /// Creates the store.
  DeferredInstallAttributionStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _pendingKey = 'daftar_pending_deep_link_token';
  static const _consumedKey = 'daftar_pending_deep_link_consumed';

  final FlutterSecureStorage _storage;

  /// Persists a token extracted from an install referrer string once.
  Future<void> captureFromReferrerString(String referrer) async {
    final token = _extractUtmContent(referrer) ??
        DeepLinkTokenParser.extractFromRaw(referrer);
    if (token == null) {
      return;
    }
    final consumed = await _storage.read(key: _consumedKey);
    if (consumed == token) {
      return;
    }
    await _storage.write(key: _pendingKey, value: token);
  }

  /// Returns and clears a pending token, marking it consumed.
  Future<String?> takePendingToken() async {
    final token = await _storage.read(key: _pendingKey);
    if (token == null || token.isEmpty) {
      return null;
    }
    await _storage.delete(key: _pendingKey);
    await _storage.write(key: _consumedKey, value: token);
    return token;
  }

  String? _extractUtmContent(String referrer) {
    try {
      final params = Uri.splitQueryString(referrer);
      final content = params['utm_content'] ?? params['token'];
      if (content == null) {
        return null;
      }
      return DeepLinkTokenParser.extractFromRaw(content);
    } on Object catch (e, st) {
      debugPrint('DeferredInstallAttributionStore parse failed: $e\n$st');
      return null;
    }
  }
}
