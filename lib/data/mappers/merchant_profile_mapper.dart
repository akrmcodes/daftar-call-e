import 'package:daftar/data/datasources/local/drift_database.dart' as db;
import 'package:daftar/domain/entities/merchant_profile.dart' as domain;
import 'package:drift/drift.dart' as drift;

/// Seamless conversions for merchant profile domain and Drift types.
extension MerchantProfileDriftMapper on db.MerchantProfileData {
  /// Converts a Drift merchant profile row back to the domain entity.
  domain.MerchantProfile toDomain() {
    return domain.MerchantProfile(
      id: id,
      storeName: storeName,
      storePhone: storePhone,
      logoPath: logoPath,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

/// Converts a domain merchant profile into a Drift companion.
extension MerchantProfileDomainMapper on domain.MerchantProfile {
  /// Returns a companion suitable for insert/update operations.
  db.MerchantProfilesCompanion toCompanion() {
    return db.MerchantProfilesCompanion(
      id: drift.Value(id),
      storeName: drift.Value(storeName),
      storePhone: drift.Value(storePhone),
      logoPath: drift.Value(logoPath),
      createdAt: drift.Value(createdAt),
      updatedAt: drift.Value(updatedAt),
    );
  }

  /// Converts a domain merchant profile directly to a Drift row.
  db.MerchantProfileData toDrift() {
    return db.MerchantProfileData(
      id: id,
      storeName: storeName,
      storePhone: storePhone,
      logoPath: logoPath,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

/// Seamless conversions for generated Drift merchant profile companions.
extension MerchantProfileCompanionMapper on db.MerchantProfilesCompanion {
  /// Reconstructs a Drift row from companion values.
  ///
  /// Assumes all fields are present (i.e. the companion was created by
  /// [MerchantProfileDomainMapper.toCompanion]).
  db.MerchantProfileData toDrift() {
    return db.MerchantProfileData(
      id: id.value,
      storeName: storeName.value,
      storePhone: storePhone.value,
      logoPath: logoPath.value,
      createdAt: createdAt.value,
      updatedAt: updatedAt.value,
    );
  }

  /// Converts a Drift companion back to the domain entity.
  domain.MerchantProfile toDomain() => toDrift().toDomain();
}
