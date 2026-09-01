import 'package:daftar/core/errors/exceptions.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/data/datasources/remote/edge_function_errors.dart';
import 'package:daftar/data/datasources/remote/workspace_member_remote_ds.dart';
import 'package:daftar/domain/entities/invite_renewal_request.dart';
import 'package:daftar/domain/entities/worker_invite_result.dart';
import 'package:daftar/domain/entities/workspace_member.dart';
import 'package:daftar/domain/enums/workspace_role.dart';
import 'package:daftar/domain/repositories/workspace_member_repository.dart';
import 'package:fpdart/fpdart.dart';

/// Remote implementation of [WorkspaceMemberRepository].
class WorkspaceMemberRepositoryImpl implements WorkspaceMemberRepository {
  const WorkspaceMemberRepositoryImpl({
    required WorkspaceMemberRemoteDs remoteDs,
  }) : _remoteDs = remoteDs;

  final WorkspaceMemberRemoteDs _remoteDs;

  @override
  Future<Either<Failure, List<WorkspaceMember>>> listMembers() async {
    try {
      final models = await _remoteDs.listMembers();
      return Right(models.map((m) => m.toDomain()).toList(growable: false));
    } on AuthException catch (error) {
      return Left(AuthFailure(error.message, code: 'sync_auth_required'));
    } on ServerException catch (error) {
      return Left(mapEdgeFunctionFailure(error));
    } on Object catch (error) {
      return Left(NetworkFailure(error.toString()));
    }
  }

  @override
  Future<Either<Failure, WorkerInviteResult>> inviteWorker({
    required String inviteeEmail,
    required WorkspaceRole role,
  }) async {
    try {
      final response = await _remoteDs.inviteWorker(
        inviteeEmail: inviteeEmail,
        role: role,
      );
      return Right(
        WorkerInviteResult(
          memberId: response.memberId,
          inviteUrl: response.inviteUrl,
          role: response.role,
          expiresAt: response.expiresAt,
          requestedRole: response.requestedRole,
          roleDowngraded: response.roleDowngraded,
        ),
      );
    } on AuthException catch (error) {
      return Left(AuthFailure(error.message, code: 'sync_auth_required'));
    } on ServerException catch (error) {
      final rateLimited = mapRateLimitedFailure(error);
      if (rateLimited != null) {
        return Left(rateLimited);
      }
      final seatCap = mapSeatCapExceededFailure(error);
      if (seatCap != null) {
        return Left(seatCap);
      }
      if (error.statusCode == 409) {
        return Left(SeatCapExceededFailure(error.message));
      }
      return Left(mapEdgeFunctionFailure(error));
    } on Object catch (error) {
      return Left(NetworkFailure(error.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> revokeInvite({required String memberId}) async {
    try {
      await _remoteDs.revokeInvite(memberId: memberId);
      return const Right(unit);
    } on AuthException catch (error) {
      return Left(AuthFailure(error.message, code: 'sync_auth_required'));
    } on ServerException catch (error) {
      return Left(mapEdgeFunctionFailure(error));
    } on Object catch (error) {
      return Left(NetworkFailure(error.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> removeMember({required String memberId}) async {
    try {
      await _remoteDs.removeMember(memberId: memberId);
      return const Right(unit);
    } on AuthException catch (error) {
      return Left(AuthFailure(error.message, code: 'sync_auth_required'));
    } on ServerException catch (error) {
      return Left(mapEdgeFunctionFailure(error));
    } on Object catch (error) {
      return Left(NetworkFailure(error.toString()));
    }
  }

  @override
  Future<Either<Failure, List<InviteRenewalRequest>>> listRenewalRequests() async {
    try {
      final models = await _remoteDs.listRenewalRequests();
      return Right(
        models
            .map(
              (model) => InviteRenewalRequest(
                id: model.id,
                workspaceId: model.workspaceId,
                originalToken: model.originalToken,
                invitedEmail: model.invitedEmail,
                createdAt: model.createdAt,
              ),
            )
            .toList(growable: false),
      );
    } on AuthException catch (error) {
      return Left(AuthFailure(error.message, code: 'sync_auth_required'));
    } on ServerException catch (error) {
      return Left(mapEdgeFunctionFailure(error));
    } on Object catch (error) {
      return Left(NetworkFailure(error.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> fulfillRenewalRequest({
    required String renewalId,
  }) async {
    try {
      await _remoteDs.fulfillRenewalRequest(renewalId: renewalId);
      return const Right(unit);
    } on AuthException catch (error) {
      return Left(AuthFailure(error.message, code: 'sync_auth_required'));
    } on ServerException catch (error) {
      return Left(mapEdgeFunctionFailure(error));
    } on Object catch (error) {
      return Left(NetworkFailure(error.toString()));
    }
  }
}
