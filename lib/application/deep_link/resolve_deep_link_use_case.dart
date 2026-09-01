import 'package:daftar/core/constants/app_constants.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/utils/deep_link_token_parser.dart';
import 'package:daftar/domain/entities/deep_link/deep_link_resolve_result.dart';
import 'package:daftar/domain/repositories/deep_link_repository.dart';
import 'package:fpdart/fpdart.dart';

/// Resolves a deep-link token without claiming (read-only preview).
///
/// Contest quarantine: when [AppConstants.kContestDisableMultiDeviceSync] is
/// true, never calls `resolve-deep-link` (Stage 8 disabled).
class ResolveDeepLinkUseCase {
  /// Creates the use case.
  const ResolveDeepLinkUseCase({
    required DeepLinkRepository deepLinkRepository,
  }) : _repository = deepLinkRepository;

  final DeepLinkRepository _repository;

  static const AuthFailure _contestQuarantined = AuthFailure(
    'Multi-device sync is disabled for this contest build.',
    code: 'contest_sync_quarantined',
  );

  /// Resolves [tokenOrUrl] (bare token or full invite URL).
  Future<Either<Failure, DeepLinkResolveResult>> call(String tokenOrUrl) async {
    // Contest quarantine — Stage 8 disabled.
    if (AppConstants.kContestDisableMultiDeviceSync) {
      return const Left(_contestQuarantined);
    }
    final token = DeepLinkTokenParser.extractFromRaw(tokenOrUrl);
    if (token == null) {
      return const Left(
        ValidationFailure('Invalid invite link', code: 'invalid_token'),
      );
    }
    return _repository.resolveToken(token);
  }
}
