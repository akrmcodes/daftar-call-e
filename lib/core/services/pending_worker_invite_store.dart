import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists a worker-invite token across sign-in interruption (Stage 8.6).
class PendingWorkerInviteStore {
  /// Creates the store.
  PendingWorkerInviteStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _pendingKey = 'daftar_pending_worker_invite_token';

  final FlutterSecureStorage _storage;

  /// Stores [token] until acceptance completes or is cleared.
  Future<void> save(String token) async {
    await _storage.write(key: _pendingKey, value: token);
  }

  /// Returns a stored token without clearing it.
  Future<String?> peek() async {
    return _storage.read(key: _pendingKey);
  }

  /// Clears any stored invite token.
  Future<void> clear() async {
    await _storage.delete(key: _pendingKey);
  }
}
