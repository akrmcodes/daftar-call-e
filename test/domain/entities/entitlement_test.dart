import 'package:daftar/domain/constants/entitlement_limits.dart';
import 'package:daftar/domain/entities/entitlement.dart';
import 'package:daftar/domain/enums/app_tier.dart';
import 'package:daftar/domain/enums/feature_flag.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Entitlement', () {
    test('defaultFree exposes free-tier limits and no premium features', () {
      final entitlement = Entitlement.defaultFree();

      expect(entitlement.tier, AppTier.free);
      expect(entitlement.maxLedgers, EntitlementLimits.freeMaxLedgers);
      expect(entitlement.maxContacts, EntitlementLimits.freeMaxContacts);
      expect(entitlement.maxTransactions, EntitlementLimits.freeMaxTransactions);
      expect(entitlement.hasFeature(FeatureFlag.brandedPdf), isFalse);
    });

    test('forPro exposes unlimited workspace and pro features', () {
      final entitlement = Entitlement.forPro();

      expect(entitlement.hasUnlimitedLedgers, isTrue);
      expect(entitlement.canAddLedger(999), isTrue);
      expect(entitlement.hasFeature(FeatureFlag.ledgerArchiving), isTrue);
      expect(entitlement.hasFeature(FeatureFlag.multiDeviceSync), isFalse);
    });

    test('forProPlus includes pro plus exclusive features', () {
      final entitlement = Entitlement.forProPlus();

      expect(entitlement.hasFeature(FeatureFlag.multiDeviceSync), isTrue);
      expect(entitlement.hasFeature(FeatureFlag.whatsappAutomation), isTrue);
    });

    test('isExpired is false when expiry is null or in the future', () {
      fakeAsync((async) {
        async.elapse(Duration.zero);
        final noExpiry = Entitlement.forPro();
        final futureExpiry = Entitlement.forPro(
          expiryDate: DateTime.utc(2026, 12, 31),
        );

        expect(noExpiry.isExpired, isFalse);
        expect(futureExpiry.isExpired, isFalse);
      });
    });

    test('isExpired is true when expiry is in the past', () {
      fakeAsync((async) {
        final entitlement = Entitlement.forPro(
          expiryDate: DateTime.utc(2026),
        );
        async.elapse(const Duration(days: 2));

        expect(entitlement.isExpired, isTrue);
        expect(entitlement.effective.tier, AppTier.free);
      });
    });

    test('canAddLedger respects exact free-tier boundary', () {
      final entitlement = Entitlement.defaultFree();

      expect(entitlement.canAddLedger(0), isTrue);
      expect(entitlement.canAddLedger(1), isFalse);
    });

    test('canAddContact respects exact free-tier boundary', () {
      final entitlement = Entitlement.defaultFree();

      expect(entitlement.canAddContact(49), isTrue);
      expect(entitlement.canAddContact(50), isFalse);
    });

    test('canAddTransaction respects exact free-tier boundary', () {
      final entitlement = Entitlement.defaultFree();

      expect(entitlement.canAddTransaction(499), isTrue);
      expect(entitlement.canAddTransaction(500), isFalse);
    });
  });
}
