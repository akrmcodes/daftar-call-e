import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/entities/entitlement.dart';
import 'package:daftar/domain/repositories/activation_repository.dart';
import 'package:fpdart/fpdart.dart';

/// Redeems a prepaid activation code and returns the resolved [Entitlement].
///
/// Business rules:
/// - Code must be non-empty after trim.
/// - Validation / offline fallback is owned by [ActivationRepository].
///
/// Failures:
/// - [ValidationFailure] when the code is empty.
/// - Repository Failure subtypes for invalid, network, or storage errors.
class ActivateCodeUseCase {
  const ActivateCodeUseCase(this._activationRepository);

  final ActivationRepository _activationRepository;

  Future<Either<Failure, Entitlement>> call(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) {
      return const Left(
        ValidationFailure(
          'Activation code is required.',
          code: 'activation_code_required',
        ),
      );
    }
    return _activationRepository.activate(trimmed);
  }
}
