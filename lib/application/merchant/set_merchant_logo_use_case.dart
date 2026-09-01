import 'dart:io';

import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/utils/merchant_logo_image_processor.dart';
import 'package:daftar/domain/entities/merchant_profile.dart';
import 'package:daftar/domain/enums/feature_flag.dart';
import 'package:daftar/domain/repositories/activation_repository.dart';
import 'package:daftar/domain/repositories/merchant_profile_repository.dart';
import 'package:fpdart/fpdart.dart';

/// Processes a picked logo image and persists its path on [MerchantProfile].
///
/// Enforces Pro/Pro+ tier via [FeatureFlag.brandedPdf], optimizes the source
/// image to a deterministic JPEG in app documents, and updates the profile.
///
/// Returns [LimitExceededFailure] when branding is locked on the free tier,
/// [ValidationFailure] when no profile exists or the image cannot be processed,
/// and repository or storage failures on read/write.
class SetMerchantLogoUseCase {
  /// Creates a use case with profile, entitlement, and documents dependencies.
  const SetMerchantLogoUseCase(
    this._merchantProfileRepository,
    this._activationRepository,
    this._documentsDirectoryResolver,
  );

  static const String _brandedPdfFeatureKey = 'brandedPdf';

  final MerchantProfileRepository _merchantProfileRepository;
  final ActivationRepository _activationRepository;
  final Future<Directory> Function() _documentsDirectoryResolver;

  /// Optimizes [sourcePath] and stores the logo path on the merchant profile.
  Future<Either<Failure, String>> execute({required String sourcePath}) async {
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

    Directory documentsDirectory;
    try {
      documentsDirectory = await _documentsDirectoryResolver();
    } on Object catch (error) {
      return Left(
        StorageFailure(
          'Could not resolve app documents directory: $error',
          code: 'merchant_logo_documents_unavailable',
        ),
      );
    }

    final optimizedPathResult =
        await MerchantLogoImageProcessor.writeOptimizedLogo(
      sourcePath: sourcePath,
      documentsDirectory: documentsDirectory,
    );
    if (optimizedPathResult.isLeft()) {
      return Left(optimizedPathResult.getLeft().toNullable()!);
    }

    final logoPath = optimizedPathResult.getRight().toNullable()!;

    final existingResult = await _merchantProfileRepository.get();
    if (existingResult.isLeft()) {
      return Left(existingResult.getLeft().toNullable()!);
    }

    final existing = existingResult.getRight().toNullable();
    if (existing == null) {
      return const Left(
        ValidationFailure(
          'Create a merchant profile before uploading a logo.',
          code: 'merchant_profile_required',
        ),
      );
    }

    final updatedProfile = existing.copyWith(
      logoPath: logoPath,
      updatedAt: DateTime.now().toUtc(),
    );

    final updateResult = await _merchantProfileRepository.update(updatedProfile);
    if (updateResult.isLeft()) {
      return Left(updateResult.getLeft().toNullable()!);
    }

    return Right(logoPath);
  }
}
