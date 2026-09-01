import 'package:daftar/core/constants/app_constants.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/utils/deep_link_token_parser.dart';
import 'package:daftar/domain/repositories/deep_link_repository.dart';
import 'package:fpdart/fpdart.dart';

/// Requests a merchant re-invite for an expired/revoked link (stub ping).
///
/// Contest quarantine: when [AppConstants.kContestDisableMultiDeviceSync] is
/// true, never calls `request-new-invite` (Stage 8 disabled).
class RequestNewInviteUseCase {
  /// Creates the use case.
  const RequestNewInviteUseCase({
    required DeepLinkRepository deepLinkRepository,
  }) : _repository = deepLinkRepository;

  final DeepLinkRepository _repository;

  static const AuthFailure _contestQuarantined = AuthFailure(
    'Multi-device sync is disabled for this contest build.',
    code: 'contest_sync_quarantined',
  );

  /// Notifies the host merchant for [tokenOrUrl].
  Future<Either<Failure, Unit>> call(String tokenOrUrl) async {
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
    return _repository.requestNewInvite(token);
  }
}
