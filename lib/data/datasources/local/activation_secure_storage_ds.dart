import 'package:daftar/core/constants/app_constants.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the signed entitlement token in platform secure storage.
class ActivationSecureStorageDs {
  ActivationSecureStorageDs({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  Future<String?> readToken() => _storage.read(
    key: AppConstants.entitlementTokenStorageKey,
  );

  Future<void> writeToken(String token) => _storage.write(
    key: AppConstants.entitlementTokenStorageKey,
    value: token,
  );

  Future<void> clearToken() => _storage.delete(
    key: AppConstants.entitlementTokenStorageKey,
  );
}
