import 'package:shared_preferences/shared_preferences.dart';

/// Persists whether the inline Pro upsell banner was permanently dismissed.
abstract final class PremiumUpgradeBannerStore {
  static const _dismissedKey = 'premium_upgrade_banner_dismissed';

  static Future<bool> get isDismissed async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_dismissedKey) ?? false;
  }

  static Future<void> dismiss() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dismissedKey, true);
  }

  /// Clears dismissal — intended for tests and future settings toggle.
  static Future<void> clearDismissal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_dismissedKey);
  }
}
