import 'dart:developer' as developer;

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Fail-soft onboarding funnel events. Never blocks completing onboarding.
abstract final class OnboardingAnalytics {
  static Future<void> logStart({required bool analyticsEnabled}) {
    return _log('onboarding_start', analyticsEnabled: analyticsEnabled);
  }

  static Future<void> logComplete({required bool analyticsEnabled}) {
    return _log('onboarding_complete', analyticsEnabled: analyticsEnabled);
  }

  static Future<void> _log(
    String name, {
    required bool analyticsEnabled,
  }) async {
    if (!analyticsEnabled || !_firebaseReady) {
      return;
    }

    try {
      await FirebaseAnalytics.instance.logEvent(name: name);
    } on Object catch (error, stackTrace) {
      developer.log(
        'OnboardingAnalytics.$name failed',
        error: error,
        stackTrace: stackTrace,
        name: 'daftar.firebase',
      );
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
