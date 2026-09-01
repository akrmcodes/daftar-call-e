import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/enums/feature_flag.dart';
import 'package:daftar/domain/repositories/activation_repository.dart';
import 'package:daftar/domain/repositories/merchant_profile_repository.dart';
import 'package:fpdart/fpdart.dart';

/// Removes the merchant logo file and clears the stored logo path.
///
/// Enforces Pro/Pro+ tier via [FeatureFlag.brandedPdf]. Returns
/// [LimitExceededFailure] on the free tier and repository failures on I/O.
class ClearMerchantLogoUseCase {
  /// Creates a use case with profile and entitlement dependencies.
  const ClearMerchantLogoUseCase(
    this._merchantProfileRepository,
    this._activationRepository,
  );

  static const String _brandedPdfFeatureKey = 'brandedPdf';

  final MerchantProfileRepository _merchantProfileRepository;
  final ActivationRepository _activationRepository;

  /// Clears the stored logo when branding is unlocked.
  Future<Either<Failure, Unit>> execute() async {
    final isBrandingUnlocked = await _activationRepository.isFeatureUnlocked(
      FeatureFlag.brandedPdf,
    );
    if (!isBrandingUnlocked) {
      return const Left(
        LimitExceededFailure(
          'Merchant branding requires a Pro subscription.',
          featureKey: _brandedPdfFeatureKey,
          currentCount: 0,
          maxAllowed: 0,
          code: 'merchant_branding_tier_locked',
        ),
      );
    }

    return _merchantProfileRepository.clearLogo();
  }
}
