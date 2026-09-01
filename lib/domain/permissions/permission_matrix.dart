import 'package:daftar/domain/enums/workspace_permission.dart';
import 'package:daftar/domain/enums/workspace_role.dart';

/// Static RBAC matrix for workspace collaboration (Stage 8.5).
///
/// Defense-in-depth companion to Postgres RLS — UI and use cases
/// must check permissions before attempting mutations.
abstract final class PermissionMatrix {
  static bool allows(WorkspaceRole? role, WorkspacePermission permission) {
    if (role == null) {
      return false;
    }

    return switch (permission) {
      WorkspacePermission.viewLedgers => true,
      WorkspacePermission.editTransactions =>
        role == WorkspaceRole.owner || role == WorkspaceRole.editor,
      WorkspacePermission.editContactsAndLedgers =>
        role == WorkspaceRole.owner || role == WorkspaceRole.editor,
      WorkspacePermission.useVoiceInput =>
        role == WorkspaceRole.owner || role == WorkspaceRole.editor,
      WorkspacePermission.sendWhatsappReminders =>
        role == WorkspaceRole.owner || role == WorkspaceRole.editor,
      WorkspacePermission.inviteWorkers => role == WorkspaceRole.owner,
      WorkspacePermission.manageBilling => role == WorkspaceRole.owner,
      WorkspacePermission.configureSharedAccounts =>
        role == WorkspaceRole.owner || role == WorkspaceRole.editor,
    };
  }
}
