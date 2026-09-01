import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Outcome of a refresh-token exchange against Google's token endpoint.
sealed class GoogleTokenRefreshResult {
  const GoogleTokenRefreshResult();
}

/// A new access token was minted from the stored refresh token.
final class GoogleTokenRefreshSuccess extends GoogleTokenRefreshResult {
  /// Creates a success result.
  const GoogleTokenRefreshSuccess({
    required this.accessToken,
    this.expiresAt,
    this.rotatedRefreshToken,
    this.idToken,
  });

  /// Fresh short-lived OAuth access token for Drive API calls.
  final String accessToken;

  /// Server-reported UTC expiry derived from `expires_in`.
  final DateTime? expiresAt;

  /// Replacement refresh token when Google rotates the grant (rare).
  final String? rotatedRefreshToken;

  /// Fresh OIDC ID token when the original grant included `openid`.
  ///
  /// Absent for legacy Drive-only PKCE grants.
  final String? idToken;
}

/// `invalid_grant` — the refresh token is permanently dead (revoked, expired
/// by Testing-mode policy, password change, or 6-month inactivity).
final class GoogleTokenRefreshRevoked extends GoogleTokenRefreshResult {
  /// Creates a revoked result.
  const GoogleTokenRefreshRevoked();
}

/// Transient failure (network, 5xx, malformed payload) — retry later.
final class GoogleTokenRefreshTransient extends GoogleTokenRefreshResult {
  /// Creates a transient result with diagnostic [message].
  const GoogleTokenRefreshTransient(this.message);

  /// Diagnostic detail for audit logs.
  final String message;
}

/// Outcome of validating an access token against Google's tokeninfo endpoint.
sealed class GoogleTokenIntrospectionResult {
  const GoogleTokenIntrospectionResult();
}

/// The access token is live; [expiresAt] is the server-reported UTC expiry.
final class GoogleTokenIntrospectionValid
    extends GoogleTokenIntrospectionResult {
  /// Creates a valid result.
  const GoogleTokenIntrospectionValid(this.expiresAt);

  /// Server-reported UTC expiry of the introspected token.
  final DateTime? expiresAt;
}

/// The access token is dead — expired or revoked server-side.
final class GoogleTokenIntrospectionInvalid
    extends GoogleTokenIntrospectionResult {
  /// Creates an invalid result.
  const GoogleTokenIntrospectionInvalid();
}

/// Introspection could not run (offline, 5xx) — token state is unknown.
final class GoogleTokenIntrospectionUnavailable
    extends GoogleTokenIntrospectionResult {
  /// Creates an unavailable result.
  const GoogleTokenIntrospectionUnavailable();
}

/// Pure-Dart refresh-token exchange (RFC 6749 §6) for installed-app clients.
///
/// Installed-app (Android/iOS) OAuth clients authenticate with PKCE at grant
/// time and require **no client secret** at the token endpoint. This class is
/// platform-channel-free, so it is safe in headless Workmanager isolates.
class GoogleTokenRefreshClient {
  /// Creates a refresher; [clientFactory] is injectable for tests.
  GoogleTokenRefreshClient({http.Client Function()? clientFactory})
      : _clientFactory = clientFactory ?? http.Client.new;

  static final Uri _tokenEndpoint =
      Uri.parse('https://oauth2.googleapis.com/token');
  static final Uri _tokenInfoEndpoint =
      Uri.parse('https://oauth2.googleapis.com/tokeninfo');
  static const Duration _timeout = Duration(seconds: 15);

  final http.Client Function() _clientFactory;

  /// Exchanges [refreshToken] for a fresh access token.
  ///
  /// Never throws — all failures collapse into a typed result so background
  /// isolates can branch without try/catch at every call site.
  Future<GoogleTokenRefreshResult> refresh({
    required String clientId,
    required String refreshToken,
  }) async {
    final client = _clientFactory();
    try {
      final response = await client.post(
        _tokenEndpoint,
        body: {
          'client_id': clientId,
          'refresh_token': refreshToken,
          'grant_type': 'refresh_token',
        },
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is! Map<String, dynamic>) {
          return const GoogleTokenRefreshTransient(
            'Token endpoint returned a non-object payload.',
          );
        }
        final accessToken = decoded['access_token'];
        if (accessToken is! String || accessToken.isEmpty) {
          return const GoogleTokenRefreshTransient(
            'Token endpoint response is missing access_token.',
          );
        }
        final rotated = decoded['refresh_token'];
        final idToken = decoded['id_token'];
        return GoogleTokenRefreshSuccess(
          accessToken: accessToken,
          expiresAt: _expiryFromExpiresIn(decoded['expires_in']),
          rotatedRefreshToken:
              rotated is String && rotated.isNotEmpty ? rotated : null,
          idToken: idToken is String && idToken.isNotEmpty ? idToken : null,
        );
      }

      if (response.statusCode == 400 || response.statusCode == 401) {
        final error = _errorField(response.body);
        if (error == 'invalid_grant') {
          return const GoogleTokenRefreshRevoked();
        }
        return GoogleTokenRefreshTransient(
          'Token endpoint rejected refresh: '
          '${error ?? 'http_${response.statusCode}'}',
        );
      }

      return GoogleTokenRefreshTransient(
        'Token endpoint returned HTTP ${response.statusCode}.',
      );
    } on Object catch (e) {
      return GoogleTokenRefreshTransient('Token refresh failed: $e');
    } finally {
      client.close();
    }
  }

  /// Validates [accessToken] against Google's tokeninfo endpoint.
  ///
  /// The Android authorization SDK can hand out cached access tokens that are
  /// already expired or revoked (documented platform limitation). This is the
  /// only way to know before a Drive call fails with 401. Never throws.
  Future<GoogleTokenIntrospectionResult> introspect(String accessToken) async {
    final client = _clientFactory();
    try {
      final response = await client
          .get(
            _tokenInfoEndpoint.replace(
              queryParameters: {'access_token': accessToken},
            ),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        DateTime? expiresAt;
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          expiresAt = _expiryFromExpiresIn(decoded['expires_in']);
        }
        return GoogleTokenIntrospectionValid(expiresAt);
      }
      if (response.statusCode == 400 || response.statusCode == 401) {
        return const GoogleTokenIntrospectionInvalid();
      }
      return const GoogleTokenIntrospectionUnavailable();
    } on Object {
      return const GoogleTokenIntrospectionUnavailable();
    } finally {
      client.close();
    }
  }

  DateTime? _expiryFromExpiresIn(Object? expiresIn) {
    final seconds = switch (expiresIn) {
      final int value => value,
      final String value => int.tryParse(value),
      _ => null,
    };
    if (seconds == null || seconds <= 0) {
      return null;
    }
    return DateTime.now().toUtc().add(Duration(seconds: seconds));
  }

  String? _errorField(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final error = decoded['error'];
        if (error is String && error.isNotEmpty) {
          return error;
        }
      }
    } on Object {
      // Fall through — body was not JSON.
    }
    return null;
  }
}
