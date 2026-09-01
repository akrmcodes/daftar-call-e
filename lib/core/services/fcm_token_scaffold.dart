import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Minimal FCM token + permission scaffold (§0.3.2).
///
/// Full token registry and server send path land in Stage 11.0. This scaffold
/// is Android-ready; iOS APNs / `aps-environment` remain Delayed.
///
/// Never throws to callers — offline-first ledger must stay usable if FCM
/// fails.
abstract final class FcmTokenScaffold {
  static StreamSubscription<String>? _tokenRefreshSubscription;

  /// Requests notification permission (Android 13+), obtains an FCM token,
  /// and listens for token refresh. Safe to call multiple times.
  static Future<void> initialize() async {
    if (!_firebaseReady) {
      return;
    }

    try {
      if (Platform.isAndroid) {
        final status = await Permission.notification.request();
        if (kDebugMode) {
          debugPrint('FcmTokenScaffold: notification permission=$status');
        }
      } else if (Platform.isIOS) {
        // iOS APNs entitlement is Delayed; still request so debug builds
        // exercise the permission sheet when APNs is later configured.
        final settings = await FirebaseMessaging.instance.requestPermission();
        if (kDebugMode) {
          debugPrint(
            'FcmTokenScaffold: iOS authStatus=${settings.authorizationStatus}',
          );
        }
      }

      final token = await FirebaseMessaging.instance.getToken();
      if (kDebugMode) {
        debugPrint('FcmTokenScaffold: fcmToken=$token');
      }

      await _tokenRefreshSubscription?.cancel();
      _tokenRefreshSubscription =
          FirebaseMessaging.instance.onTokenRefresh.listen(
        (refreshed) {
          if (kDebugMode) {
            debugPrint('FcmTokenScaffold: token refreshed=$refreshed');
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          developer.log(
            'FcmTokenScaffold.onTokenRefresh error',
            error: error,
            stackTrace: stackTrace,
            name: 'daftar.firebase',
          );
        },
      );
    } on Object catch (error, stackTrace) {
      developer.log(
        'FcmTokenScaffold.initialize failed',
        error: error,
        stackTrace: stackTrace,
        name: 'daftar.firebase',
      );
      if (kDebugMode) {
        debugPrint('FcmTokenScaffold unavailable: $error');
      }
    }
  }

  static bool get _firebaseReady {
    if (kIsWeb) {
      return false;
    }
    try {
      return Firebase.apps.isNotEmpty;
    } on Object {
      return false;
    }
  }
}
