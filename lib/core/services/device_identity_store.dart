import 'package:daftar/core/constants/app_constants.dart';
import 'package:daftar/core/utils/uuid_util.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists a stable device UUID for audit logs and sync op attribution.
///
/// Generated once on first launch and reused across process restarts.
class DeviceIdentityStore {
  /// Creates the store with optional secure storage override (tests).
  DeviceIdentityStore({FlutterSecureStorage? storage})
    : _storage = storage ?? _defaultStorage;

  static const _defaultStorage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  final FlutterSecureStorage _storage;

  /// Returns the persisted device id, creating one when absent.
  Future<String> getOrCreate() async {
    final existing = await _storage.read(
      key: AppConstants.deviceIdentityStorageKey,
    );
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final deviceId = UuidUtil.generate();
    await _storage.write(
      key: AppConstants.deviceIdentityStorageKey,
      value: deviceId,
    );
    return deviceId;
  }
}

/// Process-scoped cache for the stable device id.
///
/// Must be initialized via [initialize] during app bootstrap before any
/// repository writes audit logs.
abstract final class DeviceIdentity {
  static String? _cached;

  /// Initializes the in-memory cache from secure storage.
  static Future<void> initialize(DeviceIdentityStore store) async {
    _cached = await store.getOrCreate();
  }

  /// Initializes from a fixed id (unit tests).
  // ignore: use_setters_to_change_properties -- named test helper, not a property API
  static void initializeForTest(String deviceId) {
    _cached = deviceId;
  }

  /// The stable device id for this installation, or `null` before bootstrap.
  static String? get currentOrNull {
    final id = _cached;
    if (id == null || id.isEmpty) {
      return null;
    }
    return id;
  }

  /// The stable device id for this installation.
  static String get current {
    final id = currentOrNull;
    if (id == null) {
      throw StateError(
        'DeviceIdentity not initialized — call initialize() in bootstrap',
      );
    }
    return id;
  }
}
