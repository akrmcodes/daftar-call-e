import 'package:daftar/core/constants/app_constants.dart';
import 'package:daftar/domain/enums/workspace_permission.dart';
import 'package:daftar/domain/enums/workspace_role.dart';
import 'package:daftar/domain/permissions/permission_matrix.dart';
import 'package:daftar/presentation/providers/sync_auth_bridge_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'permissions_providers.g.dart';

/// Current workspace role for local UI gating.
///
/// Solo users without a sync membership snapshot are [WorkspaceRole.owner]
/// (Free/Pro and Pro+ before first auth-bridge). Workers keep their JWT role.
///
/// Contest quarantine: always [WorkspaceRole.owner] when Stage 8 is disabled.
@riverpod
Future<WorkspaceRole?> currentWorkspaceRole(Ref ref) {
  if (AppConstants.kContestDisableMultiDeviceSync) {
    return Future<WorkspaceRole?>.value(WorkspaceRole.owner);
  }
  return ref.watch(resolveWorkspaceRoleUseCaseProvider).call();
}

/// Whether the current user may perform [permission].
///
/// Contest quarantine: evaluate as local owner so ledger/contact screens stay
/// usable without a sync JWT.
@riverpod
Future<bool> canPerform(Ref ref, WorkspacePermission permission) async {
  if (AppConstants.kContestDisableMultiDeviceSync) {
    return PermissionMatrix.allows(WorkspaceRole.owner, permission);
  }
  final role = await ref.watch(currentWorkspaceRoleProvider.future);
  return PermissionMatrix.allows(role, permission);
}
