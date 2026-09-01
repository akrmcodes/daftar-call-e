import 'package:daftar/core/services/premium_upgrade_banner_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('PremiumUpgradeBannerStore', () {
    test('isDismissed is false by default', () async {
      expect(await PremiumUpgradeBannerStore.isDismissed, isFalse);
    });

    test('dismiss persists permanently', () async {
      await PremiumUpgradeBannerStore.dismiss();
      expect(await PremiumUpgradeBannerStore.isDismissed, isTrue);
    });

    test('clearDismissal resets state', () async {
      await PremiumUpgradeBannerStore.dismiss();
      await PremiumUpgradeBannerStore.clearDismissal();
      expect(await PremiumUpgradeBannerStore.isDismissed, isFalse);
    });
  });
}
