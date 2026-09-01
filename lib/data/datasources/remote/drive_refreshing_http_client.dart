import 'dart:async';

import 'package:daftar/data/datasources/remote/google_auth_exceptions.dart';
import 'package:http/http.dart' as http;

/// Self-healing authorized HTTP client for Google Drive calls.
///
/// Injects the current Bearer token before every request and, when Drive
/// answers **401 Unauthorized**, transparently forces one refresh-token
/// exchange and replays the request with the new token. Request bodies are
/// buffered so the replay is byte-identical.
///
/// This is the single mechanism that guarantees a Drive operation never dies
/// because an access token expired mid-flight — in the foreground UI and in
/// headless Workmanager isolates alike.
class DriveRefreshingHttpClient extends http.BaseClient {
  /// Creates a client over [getAccessToken] / [forceRefresh] credential
  /// callbacks; [inner] is injectable for tests.
  DriveRefreshingHttpClient({
    required Future<String?> Function() getAccessToken,
    required Future<String?> Function() forceRefresh,
    http.Client? inner,
  })  : _getAccessToken = getAccessToken,
        _forceRefresh = forceRefresh,
        _inner = inner ?? http.Client();

  final Future<String?> Function() _getAccessToken;
  final Future<String?> Function() _forceRefresh;
  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final token = await _getAccessToken();
    if (token == null || token.isEmpty) {
      throw const GoogleAuthNotSignedInException(
        'No Google Drive credential is available for this request.',
      );
    }

    final bodyBytes = await request.finalize().toBytes();
    final first = await _inner.send(_buildAttempt(request, bodyBytes, token));
    if (first.statusCode != 401) {
      return first;
    }

    await first.stream.drain<void>();
    final refreshed = await _forceRefresh();
    if (refreshed == null || refreshed.isEmpty || refreshed == token) {
      throw const GoogleAuthNotSignedInException(
        'Google Drive rejected the access token and it could not be '
        'refreshed.',
      );
    }
    return _inner.send(_buildAttempt(request, bodyBytes, refreshed));
  }

  http.Request _buildAttempt(
    http.BaseRequest original,
    List<int> bodyBytes,
    String token,
  ) {
    final attempt = http.Request(original.method, original.url)
      ..followRedirects = original.followRedirects
      ..maxRedirects = original.maxRedirects
      ..persistentConnection = original.persistentConnection
      ..headers.addAll(original.headers)
      ..bodyBytes = bodyBytes;
    attempt.headers['Authorization'] = 'Bearer $token';
    return attempt;
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}
