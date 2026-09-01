import 'package:daftar/application/collaboration/collaboration_gate.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/enums/workspace_permission.dart';
import 'package:daftar/domain/enums/workspace_role.dart';
import 'package:daftar/domain/repositories/activation_repository.dart';
import 'package:daftar/domain/repositories/audit_log_repository.dart';
import 'package:daftar/domain/repositories/workspace_member_repository.dart';
import 'package:fpdart/fpdart.dart';

/// Removes an active worker from the workspace (owner-only).
class RemoveWorkspaceMemberUseCase {
  const RemoveWorkspaceMemberUseCase({
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
    required int seatIndex,
  }) async {
    final denial = await CollaborationGate.requireOwnerCollaboration(
      activation: _activation,
      currentRole: currentRole,
      permission: WorkspacePermission.inviteWorkers,
    );
    if (denial != null) {
      return Left(denial);
    }

    if (seatIndex == 0) {
      return const Left(
        ValidationFailure(
          'Cannot remove the workspace owner.',
          code: 'cannot_remove_owner',
        ),
      );
    }

    final result = await _members.removeMember(memberId: memberId);
    return result.fold(
      (failure) => Future.value(Left(failure)),
      (_) async {
        await CollaborationGate.appendMembershipAudit(
          auditLog: _auditLog,
          memberId: memberId,
          action: 'DELETE',
          payload: {
            'operation': 'remove',
            'member_id': memberId,
          },
        );
        return const Right(unit);
      },
    );
  }
}
