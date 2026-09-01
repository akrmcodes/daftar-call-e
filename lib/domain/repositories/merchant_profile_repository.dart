import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/entities/merchant_profile.dart';
import 'package:fpdart/fpdart.dart';

/// Contract for merchant profile persistence operations.
///
/// Implementations must keep the domain layer free of Flutter, Drift, and
/// platform SDK dependencies.
abstract class MerchantProfileRepository {
  /// Returns the current merchant profile, or `null` if none exists.
  Future<Either<Failure, MerchantProfile?>> get();

  /// Streams the current merchant profile, or `null` when none exists.
  Stream<MerchantProfile?> watch();

  /// Persists the full merchant profile.
  Future<Either<Failure, Unit>> update(MerchantProfile profile);

  /// Updates only the stored logo path.
  Future<Either<Failure, Unit>> setLogo(String logoPath);

  /// Clears the stored logo path.
  Future<Either<Failure, Unit>> clearLogo();
}
