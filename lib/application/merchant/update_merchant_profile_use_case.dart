import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/utils/uuid_util.dart';
import 'package:daftar/domain/entities/merchant_profile.dart';
import 'package:daftar/domain/repositories/merchant_profile_repository.dart';
import 'package:daftar/domain/value_objects/phone_number.dart';
import 'package:fpdart/fpdart.dart';

/// Updates the merchant profile (store name and phone).
///
/// Name persist is **ungated** (Free and Pro). Logo remains Pro-gated in
/// `SetMerchantLogoUseCase` / branded PDF. Validates inputs and persists
/// through [MerchantProfileRepository].
///
/// Returns [ValidationFailure] for invalid name or phone, or repository
/// failures on read/write.
class UpdateMerchantProfileUseCase {
  /// Creates a use case with the merchant profile repository.
  const UpdateMerchantProfileUseCase(this._merchantProfileRepository);

  static const int _maxStoreNameLength = 100;

  final MerchantProfileRepository _merchantProfileRepository;

  /// Validates inputs, then upserts the merchant profile.
  Future<Either<Failure, MerchantProfile>> execute({
    required String storeName,
    String? storePhone,
  }) async {
    final trimmedStoreName = storeName.trim();
    if (trimmedStoreName.isEmpty) {
      return const Left(
        ValidationFailure(
          'Store name is required.',
          code: 'merchant_store_name_required',
        ),
      );
    }

    if (trimmedStoreName.length > _maxStoreNameLength) {
      return const Left(
        ValidationFailure(
          'Store name must be 100 characters or fewer.',
          code: 'merchant_store_name_too_long',
        ),
      );
    }

    final normalizedPhone = _validateOptionalPhone(storePhone);
    if (normalizedPhone.isLeft()) {
      return Left(normalizedPhone.getLeft().toNullable()!);
    }

    final existingResult = await _merchantProfileRepository.get();
    if (existingResult.isLeft()) {
      return Left(existingResult.getLeft().toNullable()!);
    }

    final existing = existingResult.getRight().toNullable();
    final now = DateTime.now().toUtc();
    final profile = existing == null
        ? MerchantProfile(
            id: UuidUtil.generate(),
            storeName: trimmedStoreName,
            storePhone: normalizedPhone.getRight().toNullable(),
            createdAt: now,
            updatedAt: now,
          )
        : existing.copyWith(
            storeName: trimmedStoreName,
            storePhone: normalizedPhone.getRight().toNullable(),
            updatedAt: now,
          );

    final updateResult = await _merchantProfileRepository.update(profile);
    if (updateResult.isLeft()) {
      return Left(updateResult.getLeft().toNullable()!);
    }

    return Right(profile);
  }

  static Either<Failure, String?> _validateOptionalPhone(String? storePhone) {
    final trimmed = storePhone?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return const Right(null);
    }

    final phone = PhoneNumber(trimmed);
    if (!phone.isValid) {
      return const Left(
        ValidationFailure(
          'Store phone number is invalid.',
          code: 'merchant_store_phone_invalid',
        ),
      );
    }

    return Right(trimmed);
  }
}
