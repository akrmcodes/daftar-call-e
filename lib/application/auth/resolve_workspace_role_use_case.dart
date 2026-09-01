import 'package:daftar/domain/enums/workspace_role.dart';
import 'package:daftar/domain/repositories/sync_auth_bridge_repository.dart';

/// Resolves the effective [WorkspaceRole] for local permission gating.
///
/// Rules:
/// - Last-known sync membership (owner/editor/viewer): use JWT role as-is.
///   Worker roles are never escalated to owner.
/// - No membership snapshot: [WorkspaceRole.owner] — covers Free/Pro solo
///   merchants and Pro+ before first sync (including debug Pro+ override).
///   Edge Functions still enforce owner JWT on invite mutations.
class ResolveWorkspaceRoleUseCase {
  /// Creates the resolver.
  const ResolveWorkspaceRoleUseCase({
    required SyncAuthBridgeRepository syncAuthBridgeRepository,
  }) : _syncAuthBridge = syncAuthBridgeRepository;

  final SyncAuthBridgeRepository _syncAuthBridge;

  /// Returns the effective role for local UI / use-case gates.
  Future<WorkspaceRole?> call() async {
    final snapshot = await _syncAuthBridge.readLastKnownMembership();
    if (snapshot != null) {
      return WorkspaceRole.fromString(snapshot.role);
    }
    return WorkspaceRole.owner;
  }
}
