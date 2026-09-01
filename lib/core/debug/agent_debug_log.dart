import 'dart:convert';
import 'dart:developer' as developer;

import 'package:daftar/core/env/env.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Debug-mode NDJSON logger for physical-device sync diagnostics.
///
/// Posts to the Cursor ingest server on the Mac host (port 7782) and mirrors
/// to the Flutter console via [developer.log].
class AgentDebugLog {
  AgentDebugLog._();

  static const String _sessionId = '1d7b1e';
  static const String _ingestPath =
      '/ingest/ed228b94-881a-43c8-b4f2-fe116cde8fe8';

  static void write({
    required String location,
    required String message,
    required String hypothesisId,
    Map<String, Object?> data = const {},
    String runId = 'pre-fix',
  }) {
    if (!kDebugMode) {
      return;
    }

    final payload = <String, Object?>{
      'sessionId': _sessionId,
      'runId': runId,
      'hypothesisId': hypothesisId,
      'location': location,
      'message': message,
      'data': data,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    // #region agent log
    final encoded = jsonEncode(payload);
    developer.log(encoded, name: 'DBG-1d7b1e');
    debugPrint('DBG-1d7b1e $encoded');
    // #endregion

    _postIngest(payload);
  }

  static void _postIngest(Map<String, Object?> payload) {
    try {
      final baseUri = Uri.parse(Env.activationApiBaseUrl);
      final ingestUri = Uri(
        scheme: baseUri.scheme,
        host: baseUri.host,
        port: 7782,
        path: _ingestPath,
      );
      Dio(
        BaseOptions(
          connectTimeout: const Duration(milliseconds: 800),
          sendTimeout: const Duration(milliseconds: 800),
          receiveTimeout: const Duration(milliseconds: 800),
        ),
      ).post<void>(
        ingestUri.toString(),
        data: payload,
        options: Options(
          headers: <String, String>{
            'Content-Type': 'application/json',
            'X-Debug-Session-Id': _sessionId,
          },
        ),
      ).ignore();
    } on Object {
      // Ingest is best-effort; console log remains the fallback.
    }
  }
}
