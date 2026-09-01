import 'package:daftar/data/datasources/local/drift_database.dart' as db;
import 'package:daftar/data/mappers/merchant_profile_mapper.dart';
import 'package:daftar/domain/entities/merchant_profile.dart' as domain;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MerchantProfile mapping', () {
    test('round-trips a fully populated entity through companion and row', () {
      // Arrange — entity with all fields populated
      final profile = domain.MerchantProfile(
        id: 'merchant-001',
        storeName: 'بقالة الأمانة',
        storePhone: '+967771234567',
        logoPath: '/data/user/0/com.daftar/files/logo.png',
        createdAt: DateTime.utc(2026, 5, 1, 8, 30),
        updatedAt: DateTime.utc(2026, 5, 15, 14),
      );

      // Act — entity → companion → domain
      final fromCompanion = profile.toCompanion().toDomain();

      // Assert
      expect(fromCompanion, equals(profile));

      // Act — entity → companion → Drift row → domain
      final fromCompanionViaDrift = profile.toCompanion().toDrift().toDomain();

      // Assert
      expect(fromCompanionViaDrift, equals(profile));

      // Act — entity → Drift row → domain
      final fromDrift = profile.toDrift().toDomain();

      // Assert
      expect(fromDrift, equals(profile));

      // Act — entity → Drift row → companion (via toCompanion) → domain
      final fromDriftViaCompanion =
          profile.toDrift().toCompanion(false).toDomain();

      // Assert
      expect(fromDriftViaCompanion, equals(profile));
    });

    test('round-trips an entity with null storePhone and null logoPath', () {
      // Arrange — entity with nullable fields set to null
      final profile = domain.MerchantProfile(
        id: 'merchant-002',
        storeName: 'متجر النور',
        createdAt: DateTime.utc(2026, 1, 10, 6),
        updatedAt: DateTime.utc(2026, 3, 20, 18, 45),
      );

      // Act — entity → companion → domain
      final fromCompanion = profile.toCompanion().toDomain();

      // Assert — nullable fields survive as null
      expect(fromCompanion, equals(profile));
      expect(fromCompanion.storePhone, isNull);
      expect(fromCompanion.logoPath, isNull);

      // Act — entity → companion → Drift row → domain
      final fromCompanionViaDrift = profile.toCompanion().toDrift().toDomain();

      // Assert
      expect(fromCompanionViaDrift, equals(profile));
      expect(fromCompanionViaDrift.storePhone, isNull);
      expect(fromCompanionViaDrift.logoPath, isNull);

      // Act — entity → Drift row → domain
      final fromDrift = profile.toDrift().toDomain();

      // Assert
      expect(fromDrift, equals(profile));
      expect(fromDrift.storePhone, isNull);
      expect(fromDrift.logoPath, isNull);
    });

    test('generated Drift row mapping stays type-safe', () {
      // Arrange — construct a MerchantProfileData directly
      final row = db.MerchantProfileData(
        id: 'merchant-003',
        storeName: 'سوبر ماركت الخير',
        storePhone: '+966501234567',
        logoPath: '/path/to/logo.jpg',
        createdAt: DateTime.utc(2026, 2, 14, 10),
        updatedAt: DateTime.utc(2026, 4, 22, 16, 30),
      );

      // This test verifies the generated row type can be constructed and
      // converted to domain without runtime errors.
      final domainEntity = row.toDomain();
      expect(domainEntity.id, equals('merchant-003'));
      expect(domainEntity.storeName, equals('سوبر ماركت الخير'));
      expect(domainEntity.storePhone, equals('+966501234567'));
      expect(domainEntity.logoPath, equals('/path/to/logo.jpg'));
    });
  });
}
