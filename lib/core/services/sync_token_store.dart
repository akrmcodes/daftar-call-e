import 'dart:async';
import 'dart:convert';

import 'package:daftar/core/constants/app_constants.dart';
import 'package:daftar/core/services/auth_session_store.dart';
import 'package:daftar/domain/entities/workspace_membership_snapshot.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the custom Supabase sync JWT in secure storage.
///
/// Separate from [AuthSessionStore] because the sync token lifecycle is
/// independent of the Google Sign-In OAuth session:
///   - Google session: long-lived, refreshed via PKCE offline grant
///   - Sync token: short-lived (1 hour), exchanged via Edge Function
///
/// ## Security Model
///
/// The sync JWT is the **sole credential** for PostgREST / Realtime access.
/// It carries `workspace_id`, `role`, and `identity_hash` — never raw email.
/// Supabase Auth is disabled; this token is issued by `verify-google-token`.
///
/// ## Persistence Contract
///
/// - [write] after every successful Edge Function token exchange.
/// - [read] before any Supabase REST / Realtime call.
/// - `delete` on sign-out (clears JWT + last-known membership).
/// - [writeLastKnownMembership] on every successful exchange (offline RBAC).
/// - `SyncTokenBundle.isExpired` checks TTL before using — triggers re-exchange if stale.
class SyncTokenStore {
  SyncTokenStore({FlutterSecureStorage? storage})
      : _storage = storage ?? _defaultStorage;

  static const _defaultStorage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  final FlutterSecureStorage _storage;

  /// Reads the stored sync token bundle, or `null` when absent or corrupt.
  Future<SyncTokenBundle?> read() async {
    try {
      final raw = await _storage.read(
        key: AppConstants.syncTokenStorageKey,
      );
      if (raw == null || raw.isEmpty) {
        return null;
      }

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Sync token payload is not a JSON object');
      }
      return SyncTokenBundle._fromJson(decoded);
    } on Object catch (error, stackTrace) {
      debugPrint('SyncTokenStore.read: corrupt payload — wiping ($error)');
      debugPrintStack(stackTrace: stackTrace);
      try {
        await _storage.delete(key: AppConstants.syncTokenStorageKey);
      } on Object catch (deleteError, deleteStack) {
        debugPrint(
          'SyncTokenStore.read: wipe after corrupt read failed ($deleteError)',
        );
        debugPrintStack(stackTrace: deleteStack);
      }
      return null;
    }
  }

  /// Atomically persists a new sync token bundle and last-known membership.
  Future<void> write(SyncTokenBundle bundle) async {
    final payload = jsonEncode(bundle._toJson());
    await _storage.write(
      key: AppConstants.syncTokenStorageKey,
      value: payload,
    );
    await writeLastKnownMembership(
      WorkspaceMembershipSnapshot(
        workspaceId: bundle.workspaceId,
        role: bundle.role,
        identityHash: bundle.identityHash,
      ),
    );
  }

  /// Persists last-known membership for Pro+ offline fail-closed RBAC.
  Future<void> writeLastKnownMembership(
    WorkspaceMembershipSnapshot snapshot,
  ) async {
    final payload = jsonEncode(<String, dynamic>{
      'workspaceId': snapshot.workspaceId,
      'role': snapshot.role,
      if (snapshot.identityHash != null) 'identityHash': snapshot.identityHash,
    });
    await _storage.write(
      key: AppConstants.syncMembershipStorageKey,
      value: payload,
    );
  }

  /// Reads last-known membership, or `null` when absent/corrupt.
  Future<WorkspaceMembershipSnapshot?> readLastKnownMembership() async {
    try {
      final raw = await _storage.read(
        key: AppConstants.syncMembershipStorageKey,
      );
      if (raw == null || raw.isEmpty) {
        return null;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Membership payload is not a JSON object');
      }
      final workspaceId = decoded['workspaceId'];
      final role = decoded['role'];
      final identityHash = decoded['identityHash'];
      if (workspaceId is! String || workspaceId.isEmpty) {
        throw const FormatException('Missing workspaceId');
      }
      if (role is! String || role.isEmpty) {
        throw const FormatException('Missing role');
      }
      return WorkspaceMembershipSnapshot(
        workspaceId: workspaceId,
        role: role,
        identityHash: identityHash is String ? identityHash : null,
      );
    } on Object catch (error, stackTrace) {
      debugPrint(
        'SyncTokenStore.readLastKnownMembership: corrupt — wiping ($error)',
      );
      debugPrintStack(stackTrace: stackTrace);
      try {
        await _storage.delete(key: AppConstants.syncMembershipStorageKey);
      } on Object catch (_) {}
      return null;
    }
  }

  /// Removes the sync token and last-known membership (sign-out).
  Future<void> delete() async {
    await _storage.delete(key: AppConstants.syncTokenStorageKey);
    await _storage.delete(key: AppConstants.syncMembershipStorageKey);
  }
}

/// Immutable snapshot of a custom sync JWT and its server-provided metadata.
///
/// Fields mirror the Edge Function response:
/// ```json
/// {
///   "sync_token": "<jwt>",
///   "expires_in": 3600,
///   "workspace_id": "<uuid>",
///   "role": "owner"
/// }
/// ```
@immutable
class SyncTokenBundle {
  const SyncTokenBundle({
    required this.syncToken,
    required this.workspaceId,
    required this.role,
    required this.obtainedAt,
    required this.expiresIn,
    this.identityHash,
  });

  factory SyncTokenBundle._fromJson(Map<String, dynamic> json) {
    final syncToken = json['syncToken'];
    final workspaceId = json['workspaceId'];
    final role = json['role'];
    final obtainedAt = json['obtainedAt'];
    final expiresIn = json['expiresIn'];
    final identityHash = json['identityHash'];

    if (syncToken is! String || syncToken.isEmpty) {
      throw const FormatException('Missing or invalid syncToken');
    }
    if (workspaceId is! String || workspaceId.isEmpty) {
      throw const FormatException('Missing or invalid workspaceId');
    }
    if (role is! String || role.isEmpty) {
      throw const FormatException('Missing or invalid role');
    }
    if (obtainedAt is! String || obtainedAt.isEmpty) {
      throw const FormatException('Missing or invalid obtainedAt');
    }
    if (expiresIn is! int || expiresIn <= 0) {
      throw const FormatException('Missing or invalid expiresIn');
    }

    return SyncTokenBundle(
      syncToken: syncToken,
      workspaceId: workspaceId,
      role: role,
      obtainedAt: DateTime.parse(obtainedAt).toUtc(),
      expiresIn: expiresIn,
      identityHash: identityHash is String && identityHash.isNotEmpty
          ? identityHash
          : null,
    );
  }

  /// The raw JWT string for PostgREST `Authorization: Bearer <token>`.
  final String syncToken;

  /// The workspace this token grants access to.
  final String workspaceId;

  /// The user's role in the workspace (`owner`, `editor`, `viewer`).
  final String role;

  /// When this token was obtained (UTC).
  final DateTime obtainedAt;

  /// Token TTL in seconds (typically 3600).
  final int expiresIn;

  /// SHA-256 identity hash from the sync JWT (optional for legacy bundles).
  final String? identityHash;

  /// Conservative expiry check with a 60-second safety margin.
  ///
  /// Triggers re-exchange before the token actually expires, preventing
  /// 401 races during active sync operations.
  bool get isExpired {
    final expiresAt = obtainedAt.add(Duration(seconds: expiresIn));
    final safeExpiry = expiresAt.subtract(const Duration(seconds: 60));
    return DateTime.now().toUtc().isAfter(safeExpiry);
  }

  /// Whether the token is still valid for use.
  bool get isValid => !isExpired;

  Map<String, dynamic> _toJson() => {
        'syncToken': syncToken,
        'workspaceId': workspaceId,
        'role': role,
        'obtainedAt': obtainedAt.toUtc().toIso8601String(),
        'expiresIn': expiresIn,
        if (identityHash != null) 'identityHash': identityHash,
      };

  @override
  String toString() =>
      'SyncTokenBundle(workspace=$workspaceId, role=$role, '
      'expired=$isExpired)';
}
