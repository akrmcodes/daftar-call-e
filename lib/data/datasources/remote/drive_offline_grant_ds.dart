import 'dart:async';
import 'dart:io';

import 'package:daftar/core/env/env.dart';
import 'package:daftar/data/datasources/remote/google_auth_exceptions.dart';
import 'package:daftar/domain/constants/auth_scopes.dart';
import 'package:flutter_appauth/flutter_appauth.dart';

typedef DriveOfflineGrant = ({
  String refreshToken,
  String clientId,
  String? accessToken,
  DateTime? accessTokenExpiresAt,
  String? idToken,
});

class DriveOfflineGrantDs {
  DriveOfflineGrantDs({FlutterAppAuth? appAuth})
      : _appAuth = appAuth ?? const FlutterAppAuth();

  static const Duration _interactiveTimeout = Duration(minutes: 3);
  static const String _clientIdSuffix = '.apps.googleusercontent.com';

  static const AuthorizationServiceConfiguration _googleServiceConfiguration =
      AuthorizationServiceConfiguration(
    authorizationEndpoint: 'https://accounts.google.com/o/oauth2/v2/auth',
    tokenEndpoint: 'https://oauth2.googleapis.com/token',
  );

  final FlutterAppAuth _appAuth;

  Future<DriveOfflineGrant?> acquire({required String loginHint}) async {
    final clientId = _platformClientId();
    try {
      final response = await _appAuth
          .authorizeAndExchangeCode(
            AuthorizationTokenRequest(
              clientId,
              _redirectUri(clientId),
              serviceConfiguration: _googleServiceConfiguration,
              scopes: AuthScopes.pkceOfflineGrantScopes,
              promptValues: const ['consent'],
              loginHint: loginHint.isNotEmpty ? loginHint : null,
              additionalParameters: const {
                'access_type': 'offline',
              },
            ),
          )
          .timeout(_interactiveTimeout);

      final refreshToken = response.refreshToken;
      if (refreshToken == null || refreshToken.isEmpty) {
        return null;
      }
      return (
        refreshToken: refreshToken,
        clientId: clientId,
        accessToken: response.accessToken,
        accessTokenExpiresAt: response.accessTokenExpirationDateTime?.toUtc(),
        idToken: response.idToken,
      );
    } on FlutterAppAuthUserCancelledException {
      throw const GoogleAuthAppAuthException(
        message: 'Drive authorization was canceled.',
        code: 'appauth_user_cancelled',
      );
    } on FlutterAppAuthPlatformException catch (error) {
      throw GoogleAuthAppAuthException(
        message: error.platformErrorDetails.errorDescription ??
            error.message ??
            'AppAuth authorization failed.',
        code: error.code,
      );
    } on TimeoutException {
      throw const GoogleAuthTimeoutException(
        'Drive authorization timed out before completing.',
      );
    }
  }

  String _platformClientId() {
    final clientId = Platform.isIOS || Platform.isMacOS
        ? Env.googleOauthClientIdIos
        : Env.googleOauthClientIdAndroid;
    if (clientId.isEmpty || !clientId.endsWith(_clientIdSuffix)) {
      throw const GoogleAuthConfigurationException(
        'GOOGLE_OAUTH_CLIENT_ID_ANDROID / _IOS is not configured. Add the '
        'platform OAuth client id to .env and regenerate envied code.',
      );
    }
    return clientId;
  }

  String _redirectUri(String clientId) {
    final prefix =
        clientId.substring(0, clientId.length - _clientIdSuffix.length);
    return 'com.googleusercontent.apps.$prefix:/oauth2redirect';
  }
}
