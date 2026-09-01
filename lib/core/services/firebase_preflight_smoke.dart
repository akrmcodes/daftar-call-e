import 'dart:developer' as developer;

import 'package:daftar/core/services/crash_logger_service.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Debug-only §0.3.2.1 preflight emitters for Crashlytics + Analytics.
///
/// Enabled exclusively when both are true:
/// - [kDebugMode]
/// - `--dart-define=DAFTAR_FIREBASE_SMOKE=true`
///
/// Never ship a permanent test-crash UI. Leave this flag off for normal
/// development so production dashboards stay clean.
abstract final class FirebasePreflightSmoke {
  static const bool _smokeDefine = bool.fromEnvironment(
    'DAFTAR_FIREBASE_SMOKE',
  );

  /// Whether the smoke harness should run on this process.
  static bool get isEnabled => kDebugMode && _smokeDefine;

  /// Fires non-fatal Crashlytics + Analytics smoke events when [isEnabled].
  ///
  /// Call **after** analytics consent has been applied so collection is on.
  /// Fail-soft: never throws to callers.
  static Future<void> runIfEnabled() async {
    if (!isEnabled) {
      return;
    }

    if (!_firebaseReady) {
      debugPrint(
        'FirebasePreflightSmoke: SKIPPED — Firebase not initialized',
      );
      return;
    }

    debugPrint('FirebasePreflightSmoke: SMOKE FIRED (starting)');
    debugPrint(
      'FirebasePreflightSmoke: For Analytics DebugView, ensure:\n'
      '  adb shell setprop debug.firebase.analytics.app com.akrmcodes.daftar\n'
      '  adb shell setprop log.tag.FA VERBOSE\n'
      '  adb shell setprop log.tag.FA-SVC VERBOSE\n'
      '  adb logcat -v time -s FA FA-SVC\n'
      'Then background ~5s / foreground, wait ≤60s on '
      'daftar-core-prod → Analytics → DebugView',
    );

    try {
      await CrashLogger.recordError(
        Exception('daftar_crashlytics_smoke'),
        StackTrace.current,
        reason: '0.3.2.1',
      );
      debugPrint(
        'FirebasePreflightSmoke: SMOKE FIRED Crashlytics '
        'non-fatal daftar_crashlytics_smoke (reason=0.3.2.1) — '
        'cold-relaunch app, then check Crashlytics console',
      );
    } on Object catch (error, stackTrace) {
      developer.log(
        'FirebasePreflightSmoke Crashlytics failed',
        error: error,
        stackTrace: stackTrace,
        name: 'daftar.firebase',
      );
      debugPrint('FirebasePreflightSmoke: Crashlytics smoke failed: $error');
    }

    try {
      // Let collection + consent settle before the first custom event.
      await Future<void>.delayed(const Duration(milliseconds: 800));
      await FirebaseAnalytics.instance.logEvent(
        name: 'daftar_analytics_smoke',
        parameters: const <String, Object>{
          'preflight': '0.3.2.1',
        },
      );
      debugPrint(
        'FirebasePreflightSmoke: SMOKE FIRED Analytics '
        'event daftar_analytics_smoke (preflight=0.3.2.1) — '
        'check FA logcat, then Firebase Analytics DebugView',
      );
    } on Object catch (error, stackTrace) {
      developer.log(
        'FirebasePreflightSmoke Analytics failed',
        error: error,
        stackTrace: stackTrace,
        name: 'daftar.firebase',
      );
      debugPrint('FirebasePreflightSmoke: Analytics smoke failed: $error');
    }

    debugPrint(
      'FirebasePreflightSmoke: FCM token is logged by FcmTokenScaffold '
      '(look for FcmTokenScaffold: fcmToken=…) — send a Console test message',
    );
    debugPrint('FirebasePreflightSmoke: SMOKE FIRED (done)');
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
