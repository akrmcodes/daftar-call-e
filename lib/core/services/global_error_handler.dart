import 'dart:async' show unawaited;

import 'package:daftar/core/services/crash_logger_service.dart';
import 'package:daftar/presentation/shared/widgets/daftar_fatal_error_view.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Installs framework-wide error hooks and the premium fatal error surface.
///
/// Called from `bootstrap()` before any widgets are built.
void configureGlobalErrorHandling() {
  FlutterError.onError = (details) {
    unawaited(
      CrashLogger.recordFlutterError(details),
    );
    if (kDebugMode) {
      FlutterError.dumpErrorToConsole(details);
    }
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    unawaited(
      CrashLogger.recordError(error, stack, fatal: true),
    );
    return true;
  };

  ErrorWidget.builder = (details) {
    unawaited(
      CrashLogger.recordFlutterError(details, fatal: false),
    );
    return DaftarFatalErrorView(details: details);
  };
}
