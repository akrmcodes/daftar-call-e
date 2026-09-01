import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/entities/workspace_membership_snapshot.dart';
import 'package:fpdart/fpdart.dart';

/// Auth Bridge port: Google ID token → short-lived sync JWT (Stage 8.2).
///
/// Implementations live in the data layer. Application/use cases must depend
/// on this interface only — never on Dio / Edge Function clients.
abstract class SyncAuthBridgeRepository {
  /// Returns a valid cached sync JWT, or exchanges a fresh Google ID token.
  Future<Either<Failure, SyncAuthCredentials>> ensureValid({
    bool allowInteractive = false,
  });

  /// Forces a fresh exchange via the Auth Bridge Edge Function.
  Future<Either<Failure, SyncAuthCredentials>> exchange({
    bool allowInteractive = false,
  });

  /// Last-known membership for offline RBAC (null when never exchanged).
  Future<WorkspaceMembershipSnapshot?> readLastKnownMembership();

  /// Clears sync JWT + last-known membership (sign-out).
  Future<Either<Failure, Unit>> clear();
}

/// Sync JWT credentials issued by `verify-google-token`.
class SyncAuthCredentials {
  /// Creates credentials from an Edge Function exchange response.
  const SyncAuthCredentials({
    required this.syncToken,
    required this.workspaceId,
    required this.role,
    required this.obtainedAt,
    required this.expiresIn,
    this.identityHash,
  });

  /// Raw JWT for `Authorization: Bearer`.
  final String syncToken;

  /// Workspace granted by this token.
  final String workspaceId;

  /// Workspace role (`owner` / `editor` / `viewer`).
  final String role;

  /// When the token was obtained (UTC).
  final DateTime obtainedAt;

  /// TTL in seconds.
  final int expiresIn;

  /// SHA-256 identity hash when present.
  final String? identityHash;

  /// Conservative validity (60s early-expiry margin).
  bool get isValid {
    final expiresAt = obtainedAt.add(Duration(seconds: expiresIn));
    final safeExpiry = expiresAt.subtract(const Duration(seconds: 60));
    return !DateTime.now().toUtc().isAfter(safeExpiry);
  }
}
