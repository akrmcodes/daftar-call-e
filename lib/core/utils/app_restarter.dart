import 'dart:io';

import 'package:flutter/services.dart';

/// Relinquishes the app process and relaunches a clean session when possible.
abstract final class AppRestarter {
  static const MethodChannel _channel = MethodChannel('daftar/app_restarter');

  static Future<void> restart() async {
    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod<void>('restartApp');
        return;
      } on Object {
        // Fall through to process exit when the platform channel is unavailable.
      }
    }
    await SystemNavigator.pop();
  }
}
