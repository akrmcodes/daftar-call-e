import 'package:daftar/application/collaboration/collaboration_gate.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/enums/workspace_permission.dart';
import 'package:daftar/domain/enums/workspace_role.dart';
import 'package:daftar/domain/repositories/activation_repository.dart';
import 'package:daftar/domain/repositories/audit_log_repository.dart';
import 'package:daftar/domain/repositories/workspace_member_repository.dart';
import 'package:fpdart/fpdart.dart';

/// Revokes a pending worker invite (owner-only).
class RevokeWorkerInviteUseCase {
  const RevokeWorkerInviteUseCase({
    required WorkspaceMemberRepository memberRepository,
    required ActivationRepository activationRepository,
    required AuditLogRepository auditLogRepository,
  })  : _members = memberRepository,
        _activation = activationRepository,
        _auditLog = auditLogRepository;

  final WorkspaceMemberRepository _members;
  final ActivationRepository _activation;
  final AuditLogRepository _auditLog;

  Future<Either<Failure, Unit>> execute({
    required WorkspaceRole? currentRole,
    required String memberId,
  }) async {
    final denial = await CollaborationGate.requireOwnerCollaboration(
      activation: _activation,
      currentRole: currentRole,
      permission: WorkspacePermission.inviteWorkers,
    );
    if (denial != null) {
      return Left(denial);
    }

    final result = await _members.revokeInvite(memberId: memberId);
    return result.fold(
      (failure) => Future.value(Left(failure)),
      (_) async {
        await CollaborationGate.appendMembershipAudit(
          auditLog: _auditLog,
          memberId: memberId,
          action: 'DELETE',
          payload: {
            'operation': 'revoke',
            'member_id': memberId,
          },
        );
        return const Right(unit);
      },
    );
  }
}
