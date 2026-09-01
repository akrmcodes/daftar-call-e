import 'package:daftar/core/constants/app_constants.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/entities/deep_link/deep_link_token_kind.dart';
import 'package:daftar/domain/repositories/deep_link_repository.dart';
import 'package:fpdart/fpdart.dart';

/// Mints a share or referral deep link (authenticated).
///
/// Contest quarantine: when [AppConstants.kContestDisableMultiDeviceSync] is
/// true, never calls `create-deep-link` (Stage 8 disabled).
class CreateDeepLinkUseCase {
  /// Creates the use case.
  const CreateDeepLinkUseCase({
    required DeepLinkRepository deepLinkRepository,
  }) : _repository = deepLinkRepository;

  final DeepLinkRepository _repository;

  static const AuthFailure _contestQuarantined = AuthFailure(
    'Multi-device sync is disabled for this contest build.',
    code: 'contest_sync_quarantined',
  );

  /// Creates a deep link of [kind] with [intentPayload].
  Future<Either<Failure, CreatedDeepLink>> call({
    required DeepLinkTokenKind kind,
    required Map<String, Object?> intentPayload,
  }) {
    // Contest quarantine — Stage 8 disabled.
    if (AppConstants.kContestDisableMultiDeviceSync) {
      return Future.value(const Left(_contestQuarantined));
    }
    if (kind == DeepLinkTokenKind.workerInvite) {
      return Future.value(
        const Left(
          ValidationFailure(
            'Use invite-worker for worker invites',
            code: 'invalid_kind',
          ),
        ),
      );
    }
    return _repository.createDeepLink(
      kind: kind,
      intentPayload: intentPayload,
    );
  }
}
