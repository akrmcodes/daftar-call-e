import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/repositories/auth_repository.dart';
import 'package:fpdart/fpdart.dart';

/// Hydrates a Google ID token for Closing Agent Send without a second picker.
///
/// Uses the PKCE refresh token (openid) on this user-initiated path. GSI
/// One Tap / account picker is never opened.
class HydrateAgentIdTokenUseCase {
  /// Creates the use case.
  const HydrateAgentIdTokenUseCase({
    required AuthRepository authRepository,
  }) : _authRepository = authRepository;

  final AuthRepository _authRepository;

  /// Returns the linked Google ID token, or [AuthFailure] when missing/mismatch.
  Future<Either<Failure, String>> execute() {
    return _authRepository.ensureLinkedIdToken(allowLightweightRestore: true);
  }
}
