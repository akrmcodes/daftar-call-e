import 'dart:convert';

import 'package:daftar/core/constants/app_constants.dart';
import 'package:daftar/domain/value_objects/auth_session_bundle.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the authoritative Auth V2 session bundle in secure storage.
///
/// OAuth tokens and session metadata MUST live here — never in
/// `SharedPreferences` or Drift.
///
/// ## Persistence contract (HARD RULE)
///
/// - Interactive sign-in MUST call [write] **before** updating Drift
///   `googleAccountId`.
/// - Sign-out MUST call [delete] **before** clearing Drift Google fields.
/// - Background isolates MUST call [read] only. The sole permitted headless
///   write is [updateLastSuccessfulSilentAuthAt].
///
/// ## Non-goals (HARD RULE — Auth V2 Phase 1.4)
///
/// - NEVER store OAuth tokens in `SharedPreferences` — secure storage only.
/// - NEVER treat Drift `googleAccountId` alone as proof of signed-in state.
/// - NEVER swallow silent auth failures on cold start — emit `needsReauth`.
class AuthSessionStore {
  /// Creates a store backed by platform secure storage.
  AuthSessionStore({FlutterSecureStorage? storage})
      : _storage = storage ?? _defaultStorage;

  static const _defaultStorage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  /// Schema v5 adds optional `cachedIdToken` / `cachedIdTokenExpiresAt`.
  /// Readers still accept v1–v4 payloads (missing ID-token keys = null).
  static const int _schemaVersion = 5;

  final FlutterSecureStorage _storage;

  /// Reads and deserializes the session bundle, or `null` when absent.
  ///
  /// Corrupt payloads are deleted and `null` is returned so bootstrap can
  /// route to `unlinked` / re-link rather than a phantom linked state.
  Future<AuthSessionBundle?> read() async {
    try {
      final raw = await _storage.read(key: AppConstants.authSessionStorageKey);
      if (raw == null || raw.isEmpty) {
        return null;
      }

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Auth session payload is not a JSON object');
      }
      return _deserialize(decoded);
    } on Object catch (error, stackTrace) {
      debugPrint('AuthSessionStore.read: corrupt payload — wiping ($error)');
      debugPrintStack(stackTrace: stackTrace);
      try {
        await delete();
      } on Object catch (deleteError, deleteStack) {
        debugPrint(
          'AuthSessionStore.read: wipe after corrupt read failed ($deleteError)',
        );
        debugPrintStack(stackTrace: deleteStack);
      }
      return null;
    }
  }

  /// Atomically serializes and persists [bundle].
  Future<void> write(AuthSessionBundle bundle) async {
    final payload = jsonEncode(_serialize(bundle));
    await _storage.write(
      key: AppConstants.authSessionStorageKey,
      value: payload,
    );
  }

  /// Removes all Auth V2 session keys from secure storage.
  Future<void> delete() async {
    await _storage.delete(key: AppConstants.authSessionStorageKey);
  }

  /// Updates only `lastSuccessfulSilentAuthAt` — permitted headless write path.
  Future<void> updateLastSuccessfulSilentAuthAt(DateTime timestamp) async {
    final existing = await read();
    if (existing == null) {
      return;
    }
    await write(existing.withSilentAuthTimestamp(timestamp));
  }

  /// Updates the cached OAuth access token — permitted headless write path.
  ///
  /// [expiresAt] carries the server-reported expiry when the token came from
  /// the token endpoint, AppAuth, or tokeninfo introspection.
  Future<void> updateCachedAccessToken(
    String accessToken, {
    DateTime? expiresAt,
  }) async {
    final existing = await read();
    if (existing == null) {
      return;
    }
    await write(
      existing.withCachedAccessToken(accessToken, expiresAt: expiresAt),
    );
  }

  /// Drops the cached access token after a Drive 401 proves it is dead —
  /// permitted headless write path.
  Future<void> clearCachedAccessToken() async {
    final existing = await read();
    if (existing == null) {
      return;
    }
    await write(existing.withoutCachedAccessToken());
  }

  /// Caches a Google ID token — user-initiated / agent path only.
  ///
  /// Not a Workmanager write. Survives hot restart for the JWT lifetime (~1h).
  Future<void> updateCachedIdToken(
    String idToken, {
    DateTime? expiresAt,
  }) async {
    final existing = await read();
    if (existing == null) {
      return;
    }
    await write(
      existing.withCachedIdToken(idToken, expiresAt: expiresAt),
    );
  }

  /// Persists the PKCE offline grant (refresh token + issuing client id).
  ///
  /// When [scopesGranted] is provided (AppAuth consent), it replaces the
  /// stored scope list so `hasOpenIdOfflineGrant` tracks the live grant.
  Future<void> updateDriveOfflineGrant({
    required String refreshToken,
    required String clientId,
    List<String>? scopesGranted,
  }) async {
    final existing = await read();
    if (existing == null) {
      return;
    }
    await write(
      existing.withDriveOfflineGrant(
        refreshToken: refreshToken,
        clientId: clientId,
        scopesGranted: scopesGranted,
      ),
    );
  }

  Map<String, dynamic> _serialize(AuthSessionBundle bundle) => {
        'schemaVersion': _schemaVersion,
        'googleUserId': bundle.googleUserId,
        'email': bundle.email,
        'displayName': bundle.displayName,
        'photoUrl': bundle.photoUrl,
        'serverClientId': bundle.serverClientId,
        'scopesGranted': bundle.scopesGranted,
        'linkedAt': bundle.linkedAt.toUtc().toIso8601String(),
        'lastSuccessfulSilentAuthAt':
            bundle.lastSuccessfulSilentAuthAt?.toUtc().toIso8601String(),
        if (bundle.cachedAccessToken != null)
          'cachedAccessToken': bundle.cachedAccessToken,
        if (bundle.cachedAccessTokenObtainedAt != null)
          'cachedAccessTokenObtainedAt':
              bundle.cachedAccessTokenObtainedAt!.toUtc().toIso8601String(),
        if (bundle.cachedAccessTokenExpiresAt != null)
          'cachedAccessTokenExpiresAt':
              bundle.cachedAccessTokenExpiresAt!.toUtc().toIso8601String(),
        if (bundle.driveRefreshToken != null)
          'driveRefreshToken': bundle.driveRefreshToken,
        if (bundle.driveTokenClientId != null)
          'driveTokenClientId': bundle.driveTokenClientId,
        if (bundle.cachedIdToken != null) 'cachedIdToken': bundle.cachedIdToken,
        if (bundle.cachedIdTokenExpiresAt != null)
          'cachedIdTokenExpiresAt':
              bundle.cachedIdTokenExpiresAt!.toUtc().toIso8601String(),
      };

  AuthSessionBundle _deserialize(Map<String, dynamic> json) {
    final version = json['schemaVersion'];
    if (version is! int || version < 1 || version > _schemaVersion) {
      throw FormatException('Unsupported auth session schema: $version');
    }

    final scopes = json['scopesGranted'];
    if (scopes is! List) {
      throw const FormatException('scopesGranted must be a JSON array');
    }

    return AuthSessionBundle.create(
      googleUserId: _requireString(json, 'googleUserId'),
      email: _requireString(json, 'email'),
      serverClientId: _requireString(json, 'serverClientId'),
      scopesGranted: scopes.map((scope) => scope.toString()).toList(),
      linkedAt: _requireDateTime(json, 'linkedAt'),
      displayName: _optionalString(json, 'displayName'),
      photoUrl: _optionalString(json, 'photoUrl'),
      lastSuccessfulSilentAuthAt:
          _optionalDateTime(json, 'lastSuccessfulSilentAuthAt'),
      cachedAccessToken: _optionalString(json, 'cachedAccessToken'),
      cachedAccessTokenObtainedAt:
          _optionalDateTime(json, 'cachedAccessTokenObtainedAt'),
      cachedAccessTokenExpiresAt:
          _optionalDateTime(json, 'cachedAccessTokenExpiresAt'),
      driveRefreshToken: _optionalString(json, 'driveRefreshToken'),
      driveTokenClientId: _optionalString(json, 'driveTokenClientId'),
      cachedIdToken: _optionalString(json, 'cachedIdToken'),
      cachedIdTokenExpiresAt: _optionalDateTime(json, 'cachedIdTokenExpiresAt'),
    );
  }
}

String _requireString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('Missing or invalid $key');
  }
  return value;
}

String? _optionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String) {
    throw FormatException('Invalid $key');
  }
  return value;
}

DateTime _requireDateTime(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('Missing or invalid $key');
  }
  return DateTime.parse(value).toUtc();
}

DateTime? _optionalDateTime(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String || value.isEmpty) {
    throw FormatException('Invalid $key');
  }
  return DateTime.parse(value).toUtc();
}
