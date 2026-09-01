import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One-shot OEM battery-unrestricted prompt for closed-app WorkManager survival.
abstract final class AutoBackupBatteryGate {
  static const String prefsKeyShown = 'auto_backup_battery_opt_prompt_shown_v1';

  static const Set<String> aggressiveOemManufacturers = {
    'xiaomi',
    'redmi',
    'poco',
    'huawei',
    'honor',
    'samsung',
    'oppo',
    'oneplus',
    'vivo',
    'realme',
    'meizu',
    'tecno',
    'infinix',
    'itel',
  };

  static Future<bool> shouldPrompt() async {
    if (!Platform.isAndroid) {
      return false;
    }
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(prefsKeyShown) ?? false) {
      return false;
    }
    if (await isIgnoringBatteryOptimizations()) {
      return false;
    }
    return isAggressiveOem();
  }

  static Future<bool> isAggressiveOem() async {
    if (!Platform.isAndroid) {
      return false;
    }
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      final manufacturer = info.manufacturer.toLowerCase().trim();
      final brand = info.brand.toLowerCase().trim();
      return aggressiveOemManufacturers.contains(manufacturer) ||
          aggressiveOemManufacturers.contains(brand);
    } on Object {
      return true;
    }
  }

  static Future<bool> isIgnoringBatteryOptimizations() async {
    if (!Platform.isAndroid) {
      return true;
    }
    try {
      return (await Permission.ignoreBatteryOptimizations.status).isGranted;
    } on Object {
      return false;
    }
  }

  static Future<bool> requestUnrestrictedBattery() async {
    if (!Platform.isAndroid) {
      return true;
    }
    try {
      final status = await Permission.ignoreBatteryOptimizations.request();
      if (status.isGranted) {
        return true;
      }
      return openAppSettings();
    } on Object {
      return openAppSettings();
    }
  }

  static Future<void> markPromptShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefsKeyShown, true);
  }
}
