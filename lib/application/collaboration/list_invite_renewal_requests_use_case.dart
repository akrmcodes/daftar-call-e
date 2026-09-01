import 'package:daftar/application/collaboration/collaboration_gate.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/entities/invite_renewal_request.dart';
import 'package:daftar/domain/enums/workspace_permission.dart';
import 'package:daftar/domain/enums/workspace_role.dart';
import 'package:daftar/domain/repositories/activation_repository.dart';
import 'package:daftar/domain/repositories/workspace_member_repository.dart';
import 'package:fpdart/fpdart.dart';

/// Lists pending invite renewal requests for the merchant Team inbox.
class ListInviteRenewalRequestsUseCase {
  const ListInviteRenewalRequestsUseCase({
    required WorkspaceMemberRepository memberRepository,
    required ActivationRepository activationRepository,
  })  : _members = memberRepository,
        _activation = activationRepository;

  final WorkspaceMemberRepository _members;
  final ActivationRepository _activation;

  Future<Either<Failure, List<InviteRenewalRequest>>> execute({
    required WorkspaceRole? currentRole,
  }) async {
    final gate = await CollaborationGate.requireOwnerCollaboration(
      activation: _activation,
      currentRole: currentRole,
      permission: WorkspacePermission.inviteWorkers,
    );
    if (gate != null) {
      return Left(gate);
    }

    return _members.listRenewalRequests();
  }
}

/// Marks a renewal request fulfilled after the owner re-sends an invite.
class FulfillInviteRenewalRequestUseCase {
  const FulfillInviteRenewalRequestUseCase({
    required WorkspaceMemberRepository memberRepository,
    required ActivationRepository activationRepository,
  })  : _members = memberRepository,
        _activation = activationRepository;

  final WorkspaceMemberRepository _members;
  final ActivationRepository _activation;

  Future<Either<Failure, Unit>> execute({
    required WorkspaceRole? currentRole,
    required String renewalId,
  }) async {
    final gate = await CollaborationGate.requireOwnerCollaboration(
      activation: _activation,
      currentRole: currentRole,
      permission: WorkspacePermission.inviteWorkers,
    );
    if (gate != null) {
      return Left(gate);
    }

    return _members.fulfillRenewalRequest(renewalId: renewalId);
  }
}
