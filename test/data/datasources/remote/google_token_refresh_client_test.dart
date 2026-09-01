import 'dart:convert';

import 'package:daftar/data/datasources/remote/google_token_refresh_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

GoogleTokenRefreshClient _clientReturning(http.Response response) {
  return GoogleTokenRefreshClient(
    clientFactory: () => MockClient((_) async => response),
  );
}

void main() {
  group('GoogleTokenRefreshClient.refresh', () {
    test('returns success with access token on HTTP 200', () async {
      final sut = _clientReturning(
        http.Response(
          jsonEncode({'access_token': 'fresh-token', 'expires_in': 3599}),
          200,
        ),
      );

      final result = await sut.refresh(
        clientId: 'client-id',
        refreshToken: 'refresh-token',
      );

      expect(result, isA<GoogleTokenRefreshSuccess>());
      expect(
        (result as GoogleTokenRefreshSuccess).accessToken,
        'fresh-token',
      );
      expect(result.rotatedRefreshToken, isNull);
      expect(result.expiresAt, isNotNull);
      expect(
        result.expiresAt!.difference(DateTime.now().toUtc()).inMinutes,
        inInclusiveRange(55, 60),
      );
    });

    test('captures id_token when the grant included openid', () async {
      final sut = _clientReturning(
        http.Response(
          jsonEncode({
            'access_token': 'fresh-token',
            'expires_in': 3599,
            'id_token': 'fresh-id-token',
          }),
          200,
        ),
      );

      final result = await sut.refresh(
        clientId: 'client-id',
        refreshToken: 'refresh-token',
      );

      expect((result as GoogleTokenRefreshSuccess).idToken, 'fresh-id-token');
    });

    test('Drive-only success when 200 payload has no id_token', () async {
      final sut = _clientReturning(
        http.Response(
          jsonEncode({'access_token': 'fresh-token', 'expires_in': 3599}),
          200,
        ),
      );

      final result = await sut.refresh(
        clientId: 'client-id',
        refreshToken: 'refresh-token',
      );

      expect((result as GoogleTokenRefreshSuccess).idToken, isNull);
    });

    test('captures rotated refresh token when Google returns one', () async {
      final sut = _clientReturning(
        http.Response(
          jsonEncode({
            'access_token': 'fresh-token',
            'refresh_token': 'rotated-refresh',
          }),
          200,
        ),
      );

      final result = await sut.refresh(
        clientId: 'client-id',
        refreshToken: 'refresh-token',
      );

      expect(
        (result as GoogleTokenRefreshSuccess).rotatedRefreshToken,
        'rotated-refresh',
      );
    });

    test('returns revoked on invalid_grant', () async {
      final sut = _clientReturning(
        http.Response(
          jsonEncode({
            'error': 'invalid_grant',
            'error_description': 'Token has been expired or revoked.',
          }),
          400,
        ),
      );

      final result = await sut.refresh(
        clientId: 'client-id',
        refreshToken: 'dead-token',
      );

      expect(result, isA<GoogleTokenRefreshRevoked>());
    });

    test('returns transient on server error', () async {
      final sut = _clientReturning(http.Response('upstream error', 503));

      final result = await sut.refresh(
        clientId: 'client-id',
        refreshToken: 'refresh-token',
      );

      expect(result, isA<GoogleTokenRefreshTransient>());
    });

    test('returns transient when the request throws', () async {
      final sut = GoogleTokenRefreshClient(
        clientFactory: () => MockClient(
          (_) async => throw http.ClientException('connection refused'),
        ),
      );

      final result = await sut.refresh(
        clientId: 'client-id',
        refreshToken: 'refresh-token',
      );

      expect(result, isA<GoogleTokenRefreshTransient>());
    });

    test('returns transient when 200 payload lacks access_token', () async {
      final sut = _clientReturning(http.Response(jsonEncode({'scope': 'x'}), 200));

      final result = await sut.refresh(
        clientId: 'client-id',
        refreshToken: 'refresh-token',
      );

      expect(result, isA<GoogleTokenRefreshTransient>());
    });
  });

  group('GoogleTokenRefreshClient.introspect', () {
    test('returns valid with server expiry on HTTP 200', () async {
      final sut = _clientReturning(
        http.Response(
          jsonEncode({'aud': 'client-id', 'expires_in': '1800'}),
          200,
        ),
      );

      final result = await sut.introspect('live-token');

      expect(result, isA<GoogleTokenIntrospectionValid>());
      final expiresAt = (result as GoogleTokenIntrospectionValid).expiresAt;
      expect(expiresAt, isNotNull);
      expect(
        expiresAt!.difference(DateTime.now().toUtc()).inMinutes,
        inInclusiveRange(25, 30),
      );
    });

    test('returns invalid on HTTP 400 (expired or revoked token)', () async {
      final sut = _clientReturning(
        http.Response(jsonEncode({'error': 'invalid_token'}), 400),
      );

      expect(
        await sut.introspect('dead-token'),
        isA<GoogleTokenIntrospectionInvalid>(),
      );
    });

    test('returns unavailable on server error', () async {
      final sut = _clientReturning(http.Response('upstream error', 503));

      expect(
        await sut.introspect('any-token'),
        isA<GoogleTokenIntrospectionUnavailable>(),
      );
    });

    test('returns unavailable when the request throws', () async {
      final sut = GoogleTokenRefreshClient(
        clientFactory: () => MockClient(
          (_) async => throw http.ClientException('offline'),
        ),
      );

      expect(
        await sut.introspect('any-token'),
        isA<GoogleTokenIntrospectionUnavailable>(),
      );
    });
  });
}
