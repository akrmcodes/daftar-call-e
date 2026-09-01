import 'dart:ui' show DartPluginRegistrant;

import 'package:daftar/core/services/device_identity_store.dart';
import 'package:daftar/data/services/backup_notification_client.dart';
import 'package:flutter/widgets.dart';

/// Primes plugins for the Workmanager background isolate.
abstract final class AutoBackupBootstrap {
  static Future<void>? _priming;

  static Future<void> prime() {
    return _priming ??= _primeOnce();
  }

  static Future<void> _primeOnce() async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    await DeviceIdentity.initialize(DeviceIdentityStore());
    await BackupNotificationClient.instance.ensureReady();
  }
}
