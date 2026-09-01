/// Last-known workspace membership for offline RBAC (Pro+ fail-closed).
///
/// Persisted on every successful Auth Bridge exchange. Used when the sync JWT
/// is missing or expired so a worker never escalates to `owner`.
class WorkspaceMembershipSnapshot {
  /// Creates an immutable membership snapshot.
  const WorkspaceMembershipSnapshot({
    required this.workspaceId,
    required this.role,
    this.identityHash,
  });

  /// Workspace the member belongs to.
  final String workspaceId;

  /// Effective role: `owner`, `editor`, or `viewer`.
  final String role;

  /// SHA-256 identity hash when known.
  final String? identityHash;
}
