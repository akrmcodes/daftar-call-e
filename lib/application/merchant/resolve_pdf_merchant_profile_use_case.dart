import 'package:daftar/domain/entities/merchant_profile.dart';
import 'package:daftar/domain/enums/feature_flag.dart';
import 'package:daftar/domain/repositories/activation_repository.dart';
import 'package:daftar/domain/repositories/merchant_profile_repository.dart';

/// Resolves the [MerchantProfile] passed to PDF export, gated on Pro/Pro+ tier.
///
/// Free-tier users always receive `null` so the PDF generator renders the default
/// app-name header. Pro/Pro+ users receive a stored profile only when
/// [FeatureFlag.brandedPdf] is unlocked and [MerchantProfile.storeName] is
/// non-empty after trim.
class ResolvePdfMerchantProfileUseCase {
  /// Creates a use case with merchant profile and entitlement dependencies.
  const ResolvePdfMerchantProfileUseCase(
    this._merchantProfileRepository,
    this._activationRepository,
  );

  final MerchantProfileRepository _merchantProfileRepository;
  final ActivationRepository _activationRepository;

  /// Loads entitlement and profile, returning the effective branding for PDF export.
  ///
  /// Repository read failures fall back to `null` (default PDF header).
  Future<MerchantProfile?> execute() async {
    final brandedPdfUnlocked = await _activationRepository.isFeatureUnlocked(
      FeatureFlag.brandedPdf,
    );
    if (!brandedPdfUnlocked) {
      return null;
    }

    final profileResult = await _merchantProfileRepository.get();
    return profileResult.fold(
      (_) => null,
      resolveBrandedProfile,
    );
  }

  /// Applies profile-content rules after tier gating has passed.
  ///
  /// Returns `null` when [profile] is missing or has an empty [MerchantProfile.storeName].
  static MerchantProfile? resolveBrandedProfile(MerchantProfile? profile) {
    if (profile == null || profile.storeName.trim().isEmpty) {
      return null;
    }

    return profile;
  }
}
