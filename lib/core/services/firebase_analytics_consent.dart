import 'dart:developer' as developer;

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Bridges `AppSettings.analyticsEnabled` to the Firebase Analytics SDK.
///
/// Fail-soft: if Firebase is uninitialized or the SDK call throws, ledger
/// CRUD continues uninterrupted (offline-first).
abstract final class FirebaseAnalyticsConsent {
  /// Applies the merchant's analytics collection preference to the SDK.
  ///
  /// Sets both [FirebaseAnalytics.setAnalyticsCollectionEnabled] and GA4
  /// consent mode ([FirebaseAnalytics.setConsent]) so events are not silently
  /// dropped when analytics storage consent is denied/defaulted.
  static Future<void> apply({required bool enabled}) async {
    if (!_firebaseReady) {
      return;
    }

    try {
      await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(enabled);
      await FirebaseAnalytics.instance.setConsent(
        analyticsStorageConsentGranted: enabled,
        // Ads signals are unused by Daftar; keep denied regardless of analytics
        // opt-in so we never imply ad tracking from the ledger opt-out toggle.
        adStorageConsentGranted: false,
        adUserDataConsentGranted: false,
        adPersonalizationSignalsConsentGranted: false,
      );
      if (kDebugMode) {
        debugPrint(
          'FirebaseAnalyticsConsent: collectionEnabled=$enabled '
          'analyticsStorageConsent=$enabled',
        );
      }
    } on Object catch (error, stackTrace) {
      developer.log(
        'FirebaseAnalyticsConsent.apply failed',
        error: error,
        stackTrace: stackTrace,
        name: 'daftar.firebase',
      );
      if (kDebugMode) {
        debugPrint('FirebaseAnalyticsConsent unavailable: $error');
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
