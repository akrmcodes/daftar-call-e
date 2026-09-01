import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:daftar/core/constants/app_constants.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// Result of a PIN validation attempt.
enum PinValidationResult {
  /// PIN matched the stored hash.
  success,

  /// No PIN has been configured.
  notConfigured,

  /// PIN format is invalid (length / non-digit).
  invalidFormat,

  /// Too many failed attempts; caller must wait for lockout to expire.
  lockedOut,

  /// PIN did not match.
  incorrect,
}

/// Banking-grade local PIN and biometric security.
///
/// PIN material is never persisted in plaintext. Only a random salt and
/// SHA-256 digest are stored in [FlutterSecureStorage]. Hash comparison uses
/// constant-time equality to mitigate timing side-channels.
class SecurityService {
  /// Creates a security service with optional test doubles.
  SecurityService({
    FlutterSecureStorage? storage,
    LocalAuthentication? localAuth,
  })  : _storage = storage ?? _defaultStorage,
        _localAuth = localAuth ?? LocalAuthentication();

  static const _defaultStorage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  final FlutterSecureStorage _storage;
  final LocalAuthentication _localAuth;

  // ── PIN lifecycle ────────────────────────────────────────────────────

  /// Whether a PIN hash and salt exist in secure storage.
  Future<bool> hasPinConfigured() async {
    final hash = await _storage.read(key: AppConstants.pinHashStorageKey);
    final salt = await _storage.read(key: AppConstants.pinSaltStorageKey);
    return hash != null &&
        hash.isNotEmpty &&
        salt != null &&
        salt.isNotEmpty;
  }

  /// Stores a new PIN after validating format.
  ///
  /// Generates a fresh 128-bit salt, hashes with SHA-256, and writes only
  /// salt + digest to secure storage. Resets the failed-attempt counter.
  Future<bool> setPin(String pin) async {
    if (!_isValidPinFormat(pin)) {
      return false;
    }

    final salt = _generateSalt();
    final hash = _hashPin(pin, salt);

    await _storage.write(
      key: AppConstants.pinSaltStorageKey,
      value: base64Encode(salt),
    );
    await _storage.write(
      key: AppConstants.pinHashStorageKey,
      value: base64Encode(hash),
    );
    await _resetFailedAttempts();
    return true;
  }

  /// Validates [pin] against the stored hash.
  ///
  /// Enforces exponential backoff after [AppConstants.maxFailedPinAttempts]
  /// consecutive failures.
  Future<PinValidationResult> validatePin(String pin) async {
    if (!_isValidPinFormat(pin)) {
      return PinValidationResult.invalidFormat;
    }

    if (!await hasPinConfigured()) {
      return PinValidationResult.notConfigured;
    }

    final lockout = await _lockoutRemaining();
    if (lockout != null) {
      return PinValidationResult.lockedOut;
    }

    final saltB64 = await _storage.read(key: AppConstants.pinSaltStorageKey);
    final hashB64 = await _storage.read(key: AppConstants.pinHashStorageKey);
    if (saltB64 == null || hashB64 == null) {
      return PinValidationResult.notConfigured;
    }

    final salt = base64Decode(saltB64);
    final storedHash = base64Decode(hashB64);
    final candidateHash = _hashPin(pin, salt);

    if (_bytesEqual(storedHash, candidateHash)) {
      await _resetFailedAttempts();
      return PinValidationResult.success;
    }

    await _recordFailedAttempt();
    final retryAfter = await _lockoutRemaining();
    if (retryAfter != null) {
      return PinValidationResult.lockedOut;
    }
    return PinValidationResult.incorrect;
  }

  /// Seconds remaining on an active lockout, or null if not locked out.
  Future<Duration?> lockoutRemaining() => _lockoutRemaining();

  /// Removes PIN salt, hash, and failed-attempt counter from secure storage.
  Future<void> clearPin() async {
    await _storage.delete(key: AppConstants.pinSaltStorageKey);
    await _storage.delete(key: AppConstants.pinHashStorageKey);
    await _resetFailedAttempts();
  }

  // ── Biometrics ───────────────────────────────────────────────────────

  /// Whether the device supports biometric or device-credential authentication.
  Future<bool> isDeviceBiometricCapable() async {
    try {
      final isSupported = await _localAuth.isDeviceSupported();
      if (!isSupported) {
        return false;
      }
      return await _localAuth.canCheckBiometrics;
    } on PlatformException {
      return false;
    }
  }

  /// Enumerates enrolled biometric types (fingerprint, face, etc.).
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      if (!await isDeviceBiometricCapable()) {
        return const [];
      }
      return _localAuth.getAvailableBiometrics();
    } on PlatformException {
      return const [];
    }
  }

  /// Prompts the user for biometric authentication.
  ///
  /// Returns `true` when authentication succeeds.
  ///
  /// Uses `persistAcrossBackgrounding` so OS prompts survive brief
  /// backgrounding during the auth flow.
  Future<bool> authenticateWithBiometrics({
    String localizedReason = 'Authenticate to unlock Daftar',
    bool biometricOnly = true,
  }) async {
    try {
      if (!await isDeviceBiometricCapable()) {
        return false;
      }
      return _localAuth.authenticate(
        localizedReason: localizedReason,
        biometricOnly: biometricOnly,
        persistAcrossBackgrounding: true,
      );
    } on PlatformException {
      return false;
    }
  }

  // ── Hashing primitives ───────────────────────────────────────────────

  /// Generates a cryptographically secure 128-bit salt.
  List<int> _generateSalt() {
    final random = Random.secure();
    return List<int>.generate(
      AppConstants.pinSaltLengthBytes,
      (_) => random.nextInt(256),
    );
  }

  /// SHA-256( salt ‖ UTF-8(pin) ).
  List<int> _hashPin(String pin, List<int> salt) {
    final input = <int>[...salt, ...utf8.encode(pin)];
    return sha256.convert(input).bytes;
  }

  static bool _isValidPinFormat(String pin) {
    return pin.length == AppConstants.pinLength &&
        RegExp(r'^\d+$').hasMatch(pin);
  }

  /// Constant-time byte comparison.
  static bool _bytesEqual(List<int> a, List<int> b) {
    if (a.length != b.length) {
      return false;
    }
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a[i] ^ b[i];
    }
    return result == 0;
  }

  // ── Failed-attempt lockout ───────────────────────────────────────────

  Future<void> _recordFailedAttempt() async {
    final raw = await _storage.read(
      key: AppConstants.pinFailedAttemptsStorageKey,
    );
    final count = (int.tryParse(raw ?? '') ?? 0) + 1;
    await _storage.write(
      key: AppConstants.pinFailedAttemptsStorageKey,
      value: count.toString(),
    );
    if (count >= AppConstants.maxFailedPinAttempts) {
      await _storage.write(
        key: _lockoutUntilKey,
        value: DateTime.now().toUtc().add(_backoffForAttempt(count)).toIso8601String(),
      );
    }
  }

  Future<void> _resetFailedAttempts() async {
    await _storage.delete(key: AppConstants.pinFailedAttemptsStorageKey);
    await _storage.delete(key: _lockoutUntilKey);
  }

  static const _lockoutUntilKey = 'daftar_pin_lockout_until';

  Future<Duration?> _lockoutRemaining() async {
    final untilRaw = await _storage.read(key: _lockoutUntilKey);
    if (untilRaw == null) {
      return null;
    }
    final until = DateTime.tryParse(untilRaw);
    if (until == null) {
      return null;
    }
    final remaining = until.difference(DateTime.now().toUtc());
    if (remaining.isNegative) {
      await _storage.delete(key: _lockoutUntilKey);
      return null;
    }
    return remaining;
  }

  static Duration _backoffForAttempt(int attemptCount) {
    // Exponential backoff: 30s, 60s, 120s, … capped at 15 minutes.
    final exponent = (attemptCount - AppConstants.maxFailedPinAttempts)
        .clamp(0, 8);
    final seconds = 30 * (1 << exponent);
    return Duration(seconds: seconds.clamp(30, 900));
  }
}
