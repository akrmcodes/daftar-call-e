import 'package:daftar/application/collaboration/collaboration_gate.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/entities/workspace_member.dart';
import 'package:daftar/domain/enums/workspace_permission.dart';
import 'package:daftar/domain/enums/workspace_role.dart';
import 'package:daftar/domain/repositories/activation_repository.dart';
import 'package:daftar/domain/repositories/workspace_member_repository.dart';
import 'package:fpdart/fpdart.dart';

/// Lists workspace members (owner-only management view).
class ListWorkspaceMembersUseCase {
  const ListWorkspaceMembersUseCase({
    required WorkspaceMemberRepository memberRepository,
    required ActivationRepository activationRepository,
  })  : _members = memberRepository,
        _activation = activationRepository;

  final WorkspaceMemberRepository _members;
  final ActivationRepository _activation;

  Future<Either<Failure, List<WorkspaceMember>>> execute({
    required WorkspaceRole? currentRole,
  }) async {
    final denial = await CollaborationGate.requireOwnerCollaboration(
      activation: _activation,
      currentRole: currentRole,
      permission: WorkspacePermission.inviteWorkers,
    );
    if (denial != null) {
      return Left(denial);
    }

    return _members.listMembers();
  }
}
