import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/entities/invite_renewal_request.dart';
import 'package:daftar/domain/entities/worker_invite_result.dart';
import 'package:daftar/domain/entities/workspace_member.dart';
import 'package:daftar/domain/enums/workspace_role.dart';
import 'package:fpdart/fpdart.dart';

/// Contract for workspace member collaboration (Stage 8.5).
abstract class WorkspaceMemberRepository {
  Future<Either<Failure, List<WorkspaceMember>>> listMembers();

  Future<Either<Failure, WorkerInviteResult>> inviteWorker({
    required String inviteeEmail,
    required WorkspaceRole role,
  });

  Future<Either<Failure, Unit>> revokeInvite({required String memberId});

  Future<Either<Failure, Unit>> removeMember({required String memberId});

  Future<Either<Failure, List<InviteRenewalRequest>>> listRenewalRequests();

  Future<Either<Failure, Unit>> fulfillRenewalRequest({
    required String renewalId,
  });
}
