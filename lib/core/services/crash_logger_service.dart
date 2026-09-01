import 'dart:developer' as developer;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Centralized crash and error reporting for Daftar.
///
/// Routes to [FirebaseCrashlytics] when Firebase has been initialized;
/// otherwise logs locally so telemetry can be enabled without code changes.
abstract final class CrashLogger {
  static bool get _crashlyticsAvailable {
    if (kIsWeb) {
      return false;
    }
    try {
      return Firebase.apps.isNotEmpty;
    } on Object {
      return false;
    }
  }

  /// Records [exception] with optional [stack] for Crashlytics or local logs.
  static Future<void> recordError(
    Object exception,
    StackTrace? stack, {
    bool fatal = false,
    String? reason,
    Iterable<Object> information = const [],
  }) async {
    developer.log(
      'CrashLogger.recordError',
      error: exception,
      stackTrace: stack,
      name: 'daftar.crash',
    );

    if (kDebugMode) {
      debugPrint(
        'CrashLogger (${fatal ? 'fatal' : 'non-fatal'}): $exception\n$stack',
      );
    }

    if (!_crashlyticsAvailable) {
      return;
    }

    try {
      await FirebaseCrashlytics.instance.recordError(
        exception,
        stack,
        fatal: fatal,
        reason: reason,
        information: information,
      );
    } on Object catch (reportingError, reportingStack) {
      developer.log(
        'Crashlytics.recordError failed',
        error: reportingError,
        stackTrace: reportingStack,
        name: 'daftar.crash',
      );
      if (kDebugMode) {
        debugPrint('Crashlytics unavailable: $reportingError');
      }
    }
  }

  /// Records a framework [FlutterErrorDetails] payload.
  static Future<void> recordFlutterError(
    FlutterErrorDetails details, {
    bool fatal = true,
  }) async {
    if (_crashlyticsAvailable) {
      try {
        if (fatal) {
          await FirebaseCrashlytics.instance.recordFlutterFatalError(details);
          return;
        }
        await FirebaseCrashlytics.instance.recordFlutterError(details);
        return;
      } on Object catch (reportingError, reportingStack) {
        developer.log(
          'Crashlytics.recordFlutterError failed',
          error: reportingError,
          stackTrace: reportingStack,
          name: 'daftar.crash',
        );
      }
    }

    await recordError(
      details.exception,
      details.stack,
      fatal: fatal,
      reason: details.library,
    );
  }
}
