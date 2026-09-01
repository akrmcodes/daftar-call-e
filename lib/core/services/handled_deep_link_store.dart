import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Tracks deep-link tokens that already routed to a terminal ceremony or accept.
///
/// Prevents `AppLinks.getInitialLink()` from reopening expired/revoked ceremony
/// on every cold start after the worker has dismissed the screen once.
class HandledDeepLinkStore {
  /// Creates the store.
  HandledDeepLinkStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _handledTokensKey = 'daftar_handled_deep_link_tokens';
  static const _maxStoredTokens = 48;

  final FlutterSecureStorage _storage;

  /// Returns true when [token] was already handled (terminal or dismissed).
  Future<bool> isHandled(String token) async {
    final normalized = token.trim();
    if (normalized.isEmpty) {
      return false;
    }
    final handled = await _readSet();
    return handled.contains(normalized);
  }

  /// Marks [token] as handled so cold-start replay is skipped.
  Future<void> markHandled(String token) async {
    final normalized = token.trim();
    if (normalized.isEmpty) {
      return;
    }
    final handled = await _readSet();
    if (handled.contains(normalized)) {
      return;
    }
    handled.add(normalized);
    while (handled.length > _maxStoredTokens) {
      handled.remove(handled.first);
    }
    await _storage.write(
      key: _handledTokensKey,
      value: jsonEncode(handled.toList(growable: false)),
    );
  }

  Future<Set<String>> _readSet() async {
    try {
      final raw = await _storage.read(key: _handledTokensKey);
      if (raw == null || raw.isEmpty) {
        return <String>{};
      }
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return <String>{};
      }
      return decoded
          .whereType<String>()
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toSet();
    } on Object catch (error, stackTrace) {
      debugPrint('HandledDeepLinkStore read failed: $error\n$stackTrace');
      return <String>{};
    }
  }
}
