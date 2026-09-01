import 'package:daftar/core/errors/exceptions.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/data/datasources/remote/deep_link_remote_ds.dart';
import 'package:daftar/data/datasources/remote/edge_function_errors.dart';
import 'package:daftar/domain/entities/deep_link/deep_link_claim_result.dart';
import 'package:daftar/domain/entities/deep_link/deep_link_resolve_result.dart';
import 'package:daftar/domain/entities/deep_link/deep_link_token_kind.dart';
import 'package:daftar/domain/repositories/deep_link_repository.dart';
import 'package:fpdart/fpdart.dart';

/// Dio-backed [DeepLinkRepository].
class DeepLinkRepositoryImpl implements DeepLinkRepository {
  /// Creates the repository.
  const DeepLinkRepositoryImpl({required DeepLinkRemoteDs remoteDs})
      : _remoteDs = remoteDs;

  final DeepLinkRemoteDs _remoteDs;

  @override
  Future<Either<Failure, DeepLinkClaimResult>> claimToken(
    String token, {
    String? googleEmail,
  }) async {
    try {
      final result = await _remoteDs.claimToken(
        token,
        googleEmail: googleEmail,
      );
      return Right(result);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message, code: 'auth'));
    } on ServerException catch (e) {
      return Left(NetworkFailure(e.message, code: 'deep_link_claim_failed'));
    } on Exception catch (e) {
      return Left(NetworkFailure('Claim failed: $e'));
    }
  }

  @override
  Future<Either<Failure, DeepLinkResolveResult>> resolveToken(
    String token,
  ) async {
    try {
      final result = await _remoteDs.resolveToken(token);
      return Right(result);
    } on ServerException catch (e) {
      return Left(NetworkFailure(e.message, code: 'deep_link_resolve_failed'));
    } on Exception catch (e) {
      return Left(NetworkFailure('Resolve failed: $e'));
    }
  }

  @override
  Future<Either<Failure, Unit>> requestNewInvite(String token) async {
    try {
      await _remoteDs.requestNewInvite(token);
      return const Right(unit);
    } on ServerException catch (e) {
      final rateLimited = mapRateLimitedFailure(e);
      if (rateLimited != null) {
        return Left(rateLimited);
      }
      return Left(NetworkFailure(e.message, code: 'deep_link_renew_failed'));
    } on Exception catch (e) {
      return Left(NetworkFailure('Renewal request failed: $e'));
    }
  }

  @override
  Future<Either<Failure, CreatedDeepLink>> createDeepLink({
    required DeepLinkTokenKind kind,
    required Map<String, Object?> intentPayload,
  }) async {
    try {
      final created = await _remoteDs.createDeepLink(
        kind: kind,
        intentPayload: intentPayload,
      );
      return Right(created);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message, code: 'auth'));
    } on ServerException catch (e) {
      final rateLimited = mapRateLimitedFailure(e);
      if (rateLimited != null) {
        return Left(rateLimited);
      }
      return Left(NetworkFailure(e.message, code: 'deep_link_create_failed'));
    } on Exception catch (e) {
      return Left(NetworkFailure('Create deep link failed: $e'));
    }
  }
}
