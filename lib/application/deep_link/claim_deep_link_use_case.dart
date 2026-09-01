import 'package:daftar/core/constants/app_constants.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/utils/deep_link_token_parser.dart';
import 'package:daftar/domain/entities/deep_link/deep_link_claim_result.dart';
import 'package:daftar/domain/repositories/deep_link_repository.dart';
import 'package:fpdart/fpdart.dart';

/// Claims a deep-link token via the Edge Function.
///
/// Contest quarantine: when [AppConstants.kContestDisableMultiDeviceSync] is
/// true, never calls `claim-deep-link` (Stage 8 disabled).
class ClaimDeepLinkUseCase {
  /// Creates the use case.
  const ClaimDeepLinkUseCase({
    required DeepLinkRepository deepLinkRepository,
  }) : _repository = deepLinkRepository;

  final DeepLinkRepository _repository;

  static const AuthFailure _contestQuarantined = AuthFailure(
    'Multi-device sync is disabled for this contest build.',
    code: 'contest_sync_quarantined',
  );

  /// Claims [tokenOrUrl] (bare token or full invite URL).
  Future<Either<Failure, DeepLinkClaimResult>> call(
    String tokenOrUrl, {
    String? googleEmail,
  }) async {
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
    return _repository.claimToken(token, googleEmail: googleEmail);
  }
}
