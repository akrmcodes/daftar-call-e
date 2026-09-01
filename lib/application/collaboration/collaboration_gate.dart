import 'dart:convert';

import 'package:daftar/core/constants/app_constants.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/enums/feature_flag.dart';
import 'package:daftar/domain/enums/workspace_permission.dart';
import 'package:daftar/domain/enums/workspace_role.dart';
import 'package:daftar/domain/permissions/permission_matrix.dart';
import 'package:daftar/domain/repositories/activation_repository.dart';
import 'package:daftar/domain/repositories/audit_log_repository.dart';

/// Shared gates and audit helpers for collaboration use cases.
abstract final class CollaborationGate {
  /// Returns a [Failure] when the action is denied, or `null` when allowed.
  static Future<Failure?> requireOwnerCollaboration({
    required ActivationRepository activation,
    required WorkspaceRole? currentRole,
    required WorkspacePermission permission,
  }) async {
    // Contest quarantine — Stage 8 disabled.
    if (AppConstants.kContestDisableMultiDeviceSync) {
      return const AuthFailure(
        'Multi-device collaboration is disabled for this contest build.',
        code: 'contest_sync_quarantined',
      );
    }

    final entitled = await activation.isFeatureUnlocked(
      FeatureFlag.multiDeviceSync,
    );
    if (!entitled) {
      return const LimitExceededFailure(
        'Multi-device collaboration requires Pro+.',
        featureKey: 'multiDeviceSync',
        currentCount: 0,
        maxAllowed: 0,
        code: 'collaboration_not_entitled',
      );
    }

    if (!PermissionMatrix.allows(currentRole, permission)) {
      return const AuthFailure(
        'You do not have permission for this action.',
        code: 'permission_denied',
      );
    }

    return null;
  }

  static Future<void> appendMembershipAudit({
    required AuditLogRepository auditLog,
    required String memberId,
    required String action,
    required Map<String, Object?> payload,
  }) async {
    await auditLog.append(
      AppendAuditLogParams(
        entityType: 'workspace_member',
        entityId: memberId,
        action: action,
        payload: jsonEncode(payload),
      ),
    );
  }
}
