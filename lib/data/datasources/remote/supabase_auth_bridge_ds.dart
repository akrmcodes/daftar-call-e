import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:daftar/core/debug/agent_debug_log.dart';
import 'package:daftar/core/env/env.dart';
import 'package:daftar/core/errors/edge_error_codes.dart';
import 'package:daftar/core/errors/exceptions.dart';
import 'package:daftar/core/services/sync_token_store.dart';
import 'package:dio/dio.dart';

/// Remote data source for the Supabase Auth Bridge (Stage 8.2).
///
/// Exchanges a Google ID Token for a short-lived custom sync JWT via the
/// `verify-google-token` Edge Function. The sync JWT is stored in
/// [SyncTokenStore] and refreshed by the sync auth bridge when expired.
class SupabaseAuthBridgeDs {
  SupabaseAuthBridgeDs({
    required Dio dio,
    required SyncTokenStore syncTokenStore,
    String? baseUrl,
    String? publishableKey,
  })  : _dio = dio,
        _syncTokenStore = syncTokenStore,
        _baseUrl = _normalizeBaseUrl(baseUrl ?? Env.activationApiBaseUrl),
        _publishableKey = publishableKey ?? Env.supabasePublishableKey;

  final Dio _dio;
  final SyncTokenStore _syncTokenStore;
  final String _baseUrl;
  final String _publishableKey;

  /// In-flight exchanges keyed by Google ID token digest (prevents
  /// cross-account contamination during concurrent account switches).
  final Map<String, Future<SyncTokenBundle>> _exchangeInFlight = {};

  static String _normalizeBaseUrl(String baseUrl) {
    return baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
  }

  static String _tokenDigest(String googleIdToken) {
    return sha256.convert(utf8.encode(googleIdToken)).toString();
  }

  Map<String, String> get _requestHeaders {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    final apiKey = _publishableKey.trim();
    if (apiKey.isNotEmpty) {
      headers['apikey'] = apiKey;
    }
    return headers;
  }

  /// Exchanges a Google ID Token for a custom sync JWT.
  ///
  /// Throws [SyncAuthException] on verification failure.
  /// Throws [ServerException] on network / server errors.
  Future<SyncTokenBundle> exchangeGoogleToken(String googleIdToken) async {
    final digest = _tokenDigest(googleIdToken);
    final existing = _exchangeInFlight[digest];
    if (existing != null) {
      return existing;
    }

    final future = _exchange(googleIdToken);
    _exchangeInFlight[digest] = future;
    try {
      return await future;
    } finally {
      final _ = _exchangeInFlight.remove(digest);
    }
  }

  Future<SyncTokenBundle> _exchange(String googleIdToken) async {
    // #region agent log
    AgentDebugLog.write(
      location: 'supabase_auth_bridge_ds.dart:_exchange',
      message: 'auth_bridge_request_start',
      hypothesisId: 'H1-auth-bridge',
      data: <String, Object?>{
        'targetHost': Uri.parse(_baseUrl).host,
        'path': '/verify-google-token',
        'hasApiKey': _publishableKey.trim().isNotEmpty,
      },
    );
    // #endregion
    try {
      final response = await _dio.post<dynamic>(
        '$_baseUrl/verify-google-token',
        data: <String, String>{'id_token': googleIdToken},
        options: Options(
          headers: _requestHeaders,
          responseType: ResponseType.json,
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );

      final data = _decodeResponseBody(response.data);
      final syncToken = _readString(data, 'sync_token');
      final expiresIn = _readInt(data, 'expires_in');
      final workspaceId = _readString(data, 'workspace_id');
      final role = _readString(data, 'role');
      final identityHash = _readString(data, 'identity_hash');

      if (syncToken == null) {
        throw const ServerException(
          'Auth bridge response missing sync_token.',
        );
      }
      if (workspaceId == null) {
        throw const ServerException(
          'Auth bridge response missing workspace_id.',
        );
      }
      if (role == null) {
        throw const ServerException(
          'Auth bridge response missing role.',
        );
      }

      final bundle = SyncTokenBundle(
        syncToken: syncToken,
        workspaceId: workspaceId,
        role: role,
        obtainedAt: DateTime.now().toUtc(),
        expiresIn: expiresIn ?? 3600,
        identityHash: identityHash,
      );

      await _syncTokenStore.write(bundle);
      // #region agent log
      AgentDebugLog.write(
        location: 'supabase_auth_bridge_ds.dart:_exchange',
        message: 'auth_bridge_success',
        hypothesisId: 'H1-auth-bridge',
        data: <String, Object?>{
          'workspaceIdPresent': workspaceId.isNotEmpty,
          'role': role,
        },
      );
      // #endregion
      return bundle;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      // #region agent log
      AgentDebugLog.write(
        location: 'supabase_auth_bridge_ds.dart:_exchange',
        message: 'auth_bridge_dio_error',
        hypothesisId: 'H1-auth-bridge',
        data: <String, Object?>{
          'dioType': e.type.name,
          'statusCode': status,
          'uriHost': e.requestOptions.uri.host,
          'uriPath': e.requestOptions.uri.path,
        },
      );
      // #endregion
      if (status == 401) {
        throw const SyncAuthException(
          'Google token verification failed. Please sign in again.',
        );
      }
      // 403 means the identity was accepted and the role refused. Re-exchanging
      // would mint the same credential and loop, so it must never be treated
      // as an expired-token signal.
      if (status == 403) {
        throw const ServerException(
          'This account is not allowed to use sync.',
          statusCode: 403,
          errorCode: EdgeErrorCodes.forbidden,
        );
      }
      if (status == 503) {
        throw ServerException(
          'Sync auth bridge temporarily unavailable.',
          statusCode: status,
        );
      }
      throw ServerException(
        e.message ?? 'Auth bridge request failed.',
        statusCode: status,
      );
    } on FormatException catch (error) {
      throw ServerException(
        'Invalid auth bridge response: $error',
      );
    }
  }

  static Map<String, dynamic> _decodeResponseBody(dynamic raw) {
    if (raw == null) {
      throw const ServerException('Empty auth bridge response.');
    }
    if (raw is String) {
      if (raw.isEmpty) {
        throw const ServerException('Empty auth bridge response.');
      }
      return _decodeResponseBody(jsonDecode(raw));
    }
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    throw const ServerException('Invalid auth bridge response shape.');
  }

  static String? _readString(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is! String || value.isEmpty) {
      return null;
    }
    return value;
  }

  static int? _readInt(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return null;
  }

  /// Returns the currently cached sync token without refreshing.
  Future<SyncTokenBundle?> getCachedToken() async {
    final cached = await _syncTokenStore.read();
    if (cached == null || cached.isExpired) {
      return null;
    }
    return cached;
  }

  /// Clears the stored sync token (sign-out path).
  Future<void> clearToken() async {
    await _syncTokenStore.delete();
  }
}

/// Exception for sync authentication failures.
class SyncAuthException implements Exception {
  const SyncAuthException(this.message);

  final String message;

  @override
  String toString() => 'SyncAuthException: $message';
}
