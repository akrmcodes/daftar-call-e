import 'dart:async' show unawaited;
import 'dart:ui' show DartPluginRegistrant;

import 'package:daftar/application/auto_backup/auto_backup_runner.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Headless entry point hosted by the native auto-backup foreground service
/// and its WorkManager fallback worker.
///
/// Must remain a top-level function so
/// `PluginUtilities.getCallbackHandle` can resolve it after reboot.
@pragma('vm:entry-point')
void autoBackupServiceMain() {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  unawaited(_runAndSignalCompletion());
}

Future<void> _runAndSignalCompletion() async {
  try {
    await AutoBackupRunner.runAutoBackup();
  } finally {
    try {
      await const MethodChannel('daftar/auto_backup_service')
          .invokeMethod<void>('taskCompleted');
    } on MissingPluginException {
      // Service already tore down the channel.
    } on Object {
      // Best-effort signal so the native host can stopSelf().
    }
  }
}
