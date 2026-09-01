import 'dart:convert';

import 'package:daftar/core/services/auth_session_store.dart';
import 'package:daftar/data/datasources/remote/google_auth_ds.dart';
import 'package:daftar/data/datasources/remote/google_token_refresh_client.dart';
import 'package:daftar/domain/constants/auth_scopes.dart';
import 'package:daftar/domain/value_objects/auth_session_bundle.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Tracks GSI platform calls so Stage 8 / Sign-In contracts can be asserted
/// without opening real Credential Manager UI.
class _TrackingGoogleSignInPlatform extends GoogleSignInPlatform {
  int lightweightCalls = 0;
  int authenticateCalls = 0;
  final List<bool> authorizationPromptFlags = <bool>[];
  List<String>? lastAuthenticateScopeHint;

  AuthenticationResults? lightweightResult;

  static const GoogleSignInUserData _user = GoogleSignInUserData(
    email: 'merchant@example.com',
    id: 'google-sub-123',
    displayName: 'Merchant',
  );

  @override
  Future<void> init(InitParameters params) async {}

  @override
  Future<AuthenticationResults?>? attemptLightweightAuthentication(
    AttemptLightweightAuthenticationParameters params,
  ) {
    lightweightCalls++;
    if (lightweightResult != null) {
      return Future<AuthenticationResults?>.value(lightweightResult);
    }
    return Future<AuthenticationResults?>.value();
  }

  @override
  bool supportsAuthenticate() => true;

  @override
  Future<AuthenticationResults> authenticate(
    AuthenticateParameters params,
  ) async {
    authenticateCalls++;
    lastAuthenticateScopeHint = List<String>.from(params.scopeHint);
    return const AuthenticationResults(
      user: _user,
      authenticationTokens: AuthenticationTokenData(idToken: 'fresh-id-token'),
    );
  }

  @override
  bool authorizationRequiresUserInteraction() => false;

  @override
  Future<ClientAuthorizationTokenData?> clientAuthorizationTokensForScopes(
    ClientAuthorizationTokensForScopesParameters params,
  ) async {
    authorizationPromptFlags.add(params.request.promptIfUnauthorized);
    // Silent miss — scopes not yet granted (no interactive authorizeScopes).
    if (!params.request.promptIfUnauthorized) {
      return null;
    }
    fail('authorizeScopes (promptIfUnauthorized: true) must not run in Sign In');
  }

  @override
  Future<ServerAuthorizationTokenData?> serverAuthorizationTokensForScopes(
    ServerAuthorizationTokensForScopesParameters params,
  ) async =>
      null;

  @override
  Future<void> signOut(SignOutParams params) async {}

  @override
  Future<void> disconnect(DisconnectParams params) async {}
}

String _unsignedJwt({
  required int exp,
  String sub = 'google-sub-123',
}) {
  final header = base64Url.encode(utf8.encode('{"alg":"none"}'));
  final payload = base64Url.encode(utf8.encode('{"exp":$exp,"sub":"$sub"}'));
  return '$header.$payload.sig';
}

GoogleTokenRefreshClient _refreshClientReturning(Map<String, Object?> body) {
  return GoogleTokenRefreshClient(
    clientFactory: () => MockClient(
      (_) async => http.Response(jsonEncode(body), 200),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, String> vault;
  late AuthSessionStore store;
  late GoogleAuthDs sut;
  late _TrackingGoogleSignInPlatform platform;

  AuthSessionBundle sampleBundle({List<String>? scopesGranted}) =>
      AuthSessionBundle.create(
        googleUserId: 'google-sub-123',
        email: 'merchant@example.com',
        serverClientId: 'web-client-id.apps.googleusercontent.com',
        scopesGranted: scopesGranted ?? AuthScopes.defaultDriveBackupScopes,
        linkedAt: DateTime.utc(2026, 6, 8, 12),
      );

  setUp(() {
    vault = <String, String>{};
    FlutterSecureStoragePlatform.instance =
        TestFlutterSecureStoragePlatform(vault);
    store = AuthSessionStore(storage: const FlutterSecureStorage());
    platform = _TrackingGoogleSignInPlatform();
    GoogleSignInPlatform.instance = platform;
    sut = GoogleAuthDs(authSessionStore: store);
  });

  tearDown(() async {
    await sut.dispose();
  });

  group('GoogleAuthDs.obtainIdToken', () {
    test(
      'allowInteractive: false never calls attemptLightweightAuthentication '
      'when linked (Stage 8 auto sync / cold start)',
      () async {
        await store.write(sampleBundle());

        final token = await sut.obtainIdToken();

        expect(token, isNull);
        expect(platform.lightweightCalls, 0);
        expect(platform.authenticateCalls, 0);
      },
    );

    test(
      'allowInteractive: true uses authenticate with Drive scopeHint and '
      'never calls lightweight restore',
      () async {
        await store.write(sampleBundle());

        final token = await sut.obtainIdToken(allowInteractive: true);

        expect(token, 'fresh-id-token');
        expect(platform.lightweightCalls, 0);
        expect(platform.authenticateCalls, 1);
        expect(
          platform.lastAuthenticateScopeHint,
          AuthScopes.defaultDriveBackupScopes,
        );
        expect(
          platform.authorizationPromptFlags,
          everyElement(isFalse),
          reason: 'Sign In must use authorizationForScopes only',
        );
      },
    );

    test(
      'allowInteractive: false returns unexpired cached ID token without '
      'authenticate or One Tap',
      () async {
        await store.write(
          sampleBundle().withCachedIdToken(
            'cached-id-token',
            expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
          ),
        );

        final token = await sut.obtainIdToken();

        expect(token, 'cached-id-token');
        expect(platform.lightweightCalls, 0);
        expect(platform.authenticateCalls, 0);
      },
    );

    test(
      'allowInteractive: false ignores expired cached ID token',
      () async {
        await store.write(
          sampleBundle().withCachedIdToken(
            'stale-id-token',
            expiresAt: DateTime.now().toUtc().subtract(const Duration(minutes: 5)),
          ),
        );

        final token = await sut.obtainIdToken();

        expect(token, isNull);
        expect(platform.lightweightCalls, 0);
        expect(platform.authenticateCalls, 0);
      },
    );
  });

  group('GoogleAuthDs.hydrateLinkedIdToken', () {
    test(
      'returns cached token without lightweight restore',
      () async {
        await store.write(
          sampleBundle().withCachedIdToken(
            'cached-id-token',
            expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
          ),
        );

        final result = await sut.hydrateLinkedIdToken();

        expect(result, isA<LinkedIdTokenReady>());
        expect((result as LinkedIdTokenReady).token, 'cached-id-token');
        expect(platform.lightweightCalls, 0);
        expect(platform.authenticateCalls, 0);
      },
    );

    test(
      'mints ID token from PKCE refresh without GSI UI',
      () async {
        final exp = DateTime.now()
                .toUtc()
                .add(const Duration(hours: 1))
                .millisecondsSinceEpoch ~/
            1000;
        final jwt = _unsignedJwt(exp: exp);
        await store.write(
          sampleBundle(scopesGranted: AuthScopes.pkceOfflineGrantScopes)
              .withDriveOfflineGrant(
            refreshToken: 'pkce-refresh-token',
            clientId: 'android-client.apps.googleusercontent.com',
          ),
        );
        sut = GoogleAuthDs(
          authSessionStore: store,
          tokenRefreshClient: _refreshClientReturning({
            'access_token': 'fresh-access-token',
            'expires_in': 3600,
            'id_token': jwt,
          }),
        );

        final result = await sut.hydrateLinkedIdToken();

        expect(result, isA<LinkedIdTokenReady>());
        expect((result as LinkedIdTokenReady).token, jwt);
        expect(platform.lightweightCalls, 0);
        expect(platform.authenticateCalls, 0);
        final persisted = await store.read();
        expect(persisted?.cachedIdToken, jwt);
        expect(persisted?.cachedAccessToken, 'fresh-access-token');
      },
    );

    test(
      'fail-closed when PKCE ID token sub does not match the bundle',
      () async {
        final exp = DateTime.now()
                .toUtc()
                .add(const Duration(hours: 1))
                .millisecondsSinceEpoch ~/
            1000;
        final jwt = _unsignedJwt(exp: exp, sub: 'other-google-sub');
        await store.write(
          sampleBundle(scopesGranted: AuthScopes.pkceOfflineGrantScopes)
              .withDriveOfflineGrant(
            refreshToken: 'pkce-refresh-token',
            clientId: 'android-client.apps.googleusercontent.com',
          ),
        );
        sut = GoogleAuthDs(
          authSessionStore: store,
          tokenRefreshClient: _refreshClientReturning({
            'access_token': 'fresh-access-token',
            'id_token': jwt,
          }),
        );

        final result = await sut.hydrateLinkedIdToken();

        expect(result, isA<LinkedIdTokenMismatch>());
        expect(platform.lightweightCalls, 0);
        expect(platform.authenticateCalls, 0);
        final persisted = await store.read();
        expect(persisted?.cachedIdToken, isNull);
      },
    );

    test(
      'returns openid upgrade when Drive grant lacks openid',
      () async {
        await store.write(
          sampleBundle().withDriveOfflineGrant(
            refreshToken: 'legacy-refresh-token',
            clientId: 'android-client.apps.googleusercontent.com',
          ),
        );

        final result = await sut.hydrateLinkedIdToken();

        expect(result, isA<LinkedIdTokenNeedsOpenIdGrant>());
        expect(platform.lightweightCalls, 0);
        expect(platform.authenticateCalls, 0);
      },
    );

    test(
      'returns missing when unlinked (no bundle, no picker)',
      () async {
        final result = await sut.hydrateLinkedIdToken();

        expect(result, isA<LinkedIdTokenMissing>());
        expect(platform.authenticateCalls, 0);
        expect(platform.lightweightCalls, 0);
      },
    );

    test(
      'openid grant without id_token on refresh requires re-consent',
      () async {
        await store.write(
          sampleBundle(scopesGranted: AuthScopes.pkceOfflineGrantScopes)
              .withDriveOfflineGrant(
            refreshToken: 'pkce-refresh-token',
            clientId: 'android-client.apps.googleusercontent.com',
          ),
        );
        sut = GoogleAuthDs(
          authSessionStore: store,
          tokenRefreshClient: _refreshClientReturning({
            'access_token': 'fresh-access-token',
            'expires_in': 3600,
          }),
        );

        final result = await sut.hydrateLinkedIdToken();

        expect(result, isA<LinkedIdTokenNeedsOpenIdGrant>());
        expect(platform.lightweightCalls, 0);
        expect(platform.authenticateCalls, 0);
      },
    );
  });

  group('GoogleAuthDs.ensureDriveCredential', () {
    test('piggybacks id_token onto Drive refresh when present', () async {
      final exp = DateTime.now()
              .toUtc()
              .add(const Duration(hours: 1))
              .millisecondsSinceEpoch ~/
          1000;
      final jwt = _unsignedJwt(exp: exp);
      await store.write(
        sampleBundle(scopesGranted: AuthScopes.pkceOfflineGrantScopes)
            .withDriveOfflineGrant(
          refreshToken: 'pkce-refresh-token',
          clientId: 'android-client.apps.googleusercontent.com',
        ),
      );
      sut = GoogleAuthDs(
        authSessionStore: store,
        tokenRefreshClient: _refreshClientReturning({
          'access_token': 'fresh-access-token',
          'expires_in': 3600,
          'id_token': jwt,
        }),
      );

      final status = await sut.ensureDriveCredential();

      expect(status, DriveCredentialStatus.ready);
      final persisted = await store.read();
      expect(persisted?.cachedAccessToken, 'fresh-access-token');
      expect(persisted?.cachedIdToken, jwt);
      expect(platform.lightweightCalls, 0);
      expect(platform.authenticateCalls, 0);
    });
  });

  group('GoogleAuthDs.signIn Drive grant', () {
    test(
      'passes scopeHint and never prompts authorizeScopes after authenticate',
      () async {
        final account = await sut.signIn();

        expect(account, isNotNull);
        expect(account!.id, 'google-sub-123');
        expect(
          platform.lastAuthenticateScopeHint,
          AuthScopes.defaultDriveBackupScopes,
        );
        expect(
          platform.authorizationPromptFlags,
          everyElement(isFalse),
        );
        expect(
          platform.authorizationPromptFlags,
          isNotEmpty,
          reason: 'silent authorizationForScopes should still be attempted',
        );
      },
    );
  });
}
