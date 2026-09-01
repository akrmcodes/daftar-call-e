import 'package:freezed_annotation/freezed_annotation.dart';

part 'merchant_profile.freezed.dart';

/// Represents the merchant's branded profile information used by local data
/// and future PDF/header rendering.
///
/// This entity is pure domain data only. UI concerns are deferred to later
/// roadmap stages.
@freezed
abstract class MerchantProfile with _$MerchantProfile {
  const factory MerchantProfile({
    required String id,
    required String storeName,
    required DateTime createdAt,
    required DateTime updatedAt,
    String? storePhone,
    String? logoPath,
  }) = _MerchantProfile;
}
