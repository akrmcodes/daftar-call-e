import 'package:daftar/application/collaboration/collaboration_gate.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/entities/worker_invite_result.dart';
import 'package:daftar/domain/enums/workspace_permission.dart';
import 'package:daftar/domain/enums/workspace_role.dart';
import 'package:daftar/domain/repositories/activation_repository.dart';
import 'package:daftar/domain/repositories/audit_log_repository.dart';
import 'package:daftar/domain/repositories/workspace_member_repository.dart';
import 'package:fpdart/fpdart.dart';

/// Invites a worker by email (owner-only, Pro+ gated).
class InviteWorkerUseCase {
  const InviteWorkerUseCase({
    required WorkspaceMemberRepository memberRepository,
    required ActivationRepository activationRepository,
    required AuditLogRepository auditLogRepository,
  })  : _members = memberRepository,
        _activation = activationRepository,
        _auditLog = auditLogRepository;

  final WorkspaceMemberRepository _members;
  final ActivationRepository _activation;
  final AuditLogRepository _auditLog;

  Future<Either<Failure, WorkerInviteResult>> execute({
    required WorkspaceRole? currentRole,
    required String inviteeEmail,
    required WorkspaceRole inviteRole,
  }) async {
    final denial = await CollaborationGate.requireOwnerCollaboration(
      activation: _activation,
      currentRole: currentRole,
      permission: WorkspacePermission.inviteWorkers,
    );
    if (denial != null) {
      return Left(denial);
    }

    if (inviteRole == WorkspaceRole.owner) {
      return const Left(
        ValidationFailure(
          'Cannot invite as owner.',
          code: 'invalid_invite_role',
        ),
      );
    }

    final normalizedEmail = inviteeEmail.trim().toLowerCase();
    if (!normalizedEmail.contains('@')) {
      return const Left(
        ValidationFailure('Invalid email address.', code: 'invalid_email'),
      );
    }

    final result = await _members.inviteWorker(
      inviteeEmail: normalizedEmail,
      role: inviteRole,
    );

    return result.fold(
      (failure) => Future.value(Left(failure)),
      (invite) async {
        await CollaborationGate.appendMembershipAudit(
          auditLog: _auditLog,
          memberId: invite.memberId,
          action: 'CREATE',
          payload: {
            'operation': 'invite',
            'invited_email': normalizedEmail,
            'role': invite.role.name,
            'status': 'pending',
          },
        );
        return Right(invite);
      },
    );
  }
}
