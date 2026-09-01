import 'package:daftar/domain/constants/auth_scopes.dart';
import 'package:daftar/domain/value_objects/auth_session_bundle.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthSessionBundle.create', () {
    final linkedAt = DateTime.utc(2026, 6, 8, 12);

    AuthSessionBundle validBundle() => AuthSessionBundle.create(
          googleUserId: 'google-sub-123',
          email: 'merchant@example.com',
          displayName: ' Merchant ',
          serverClientId: 'web-client-id.apps.googleusercontent.com',
          scopesGranted: AuthScopes.defaultDriveBackupScopes,
          linkedAt: linkedAt,
        );

    test('creates bundle with normalized fields', () {
      final bundle = validBundle();

      expect(bundle.googleUserId, 'google-sub-123');
      expect(bundle.email, 'merchant@example.com');
      expect(bundle.displayName, 'Merchant');
      expect(bundle.serverClientId, 'web-client-id.apps.googleusercontent.com');
      expect(bundle.scopesGranted, AuthScopes.defaultDriveBackupScopes);
      expect(bundle.linkedAt, linkedAt);
      expect(bundle.lastSuccessfulSilentAuthAt, isNull);
      expect(bundle.hasDriveAppDataScope, isTrue);
    });

    test('normalizes local timestamps to UTC', () {
      final local = DateTime(2026, 6, 8, 15);
      final bundle = AuthSessionBundle.create(
        googleUserId: 'id',
        email: 'a@b.com',
        serverClientId: 'client',
        scopesGranted: const ['scope'],
        linkedAt: local,
        lastSuccessfulSilentAuthAt: local,
      );

      expect(bundle.linkedAt.isUtc, isTrue);
      expect(bundle.lastSuccessfulSilentAuthAt!.isUtc, isTrue);
    });

    test('rejects empty googleUserId', () {
      expect(
        () => AuthSessionBundle.create(
          googleUserId: '   ',
          email: 'a@b.com',
          serverClientId: 'client',
          scopesGranted: const ['scope'],
          linkedAt: linkedAt,
        ),
        throwsArgumentError,
      );
    });

    test('rejects invalid email', () {
      expect(
        () => AuthSessionBundle.create(
          googleUserId: 'id',
          email: 'not-an-email',
          serverClientId: 'client',
          scopesGranted: const ['scope'],
          linkedAt: linkedAt,
        ),
        throwsArgumentError,
      );
    });

    test('rejects empty scopesGranted', () {
      expect(
        () => AuthSessionBundle.create(
          googleUserId: 'id',
          email: 'a@b.com',
          serverClientId: 'client',
          scopesGranted: const [],
          linkedAt: linkedAt,
        ),
        throwsArgumentError,
      );
    });

    test('withSilentAuthTimestamp updates UTC timestamp', () {
      final bundle = validBundle();
      final silentAt = DateTime.utc(2026, 6, 8, 18, 30);
      final updated = bundle.withSilentAuthTimestamp(silentAt);

      expect(updated.lastSuccessfulSilentAuthAt, silentAt);
    });

    test('hasValidCachedAccessToken is false when token absent', () {
      expect(validBundle().hasValidCachedAccessToken, isFalse);
    });

    test('hasValidCachedAccessToken is true within TTL', () {
      final bundle = validBundle().withCachedAccessToken('access-token-xyz');

      expect(bundle.hasValidCachedAccessToken, isTrue);
      expect(bundle.cachedAccessToken, 'access-token-xyz');
      expect(bundle.cachedAccessTokenObtainedAt, isNotNull);
    });

    test('hasValidCachedAccessToken is false when token expired', () {
      final bundle = AuthSessionBundle.create(
        googleUserId: 'id',
        email: 'a@b.com',
        serverClientId: 'client',
        scopesGranted: const ['scope'],
        linkedAt: linkedAt,
        cachedAccessToken: 'stale-token',
        cachedAccessTokenObtainedAt:
            DateTime.now().toUtc().subtract(const Duration(hours: 2)),
      );

      expect(bundle.hasValidCachedAccessToken, isFalse);
    });

    test('server-reported expiry overrides the legacy TTL window', () {
      final bundle = validBundle().withCachedAccessToken(
        'token-with-known-expiry',
        expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 30)),
      );

      expect(bundle.hasValidCachedAccessToken, isTrue);
      expect(bundle.cachedAccessTokenExpiresAt, isNotNull);
    });

    test('token within the expiry safety margin is treated as dead', () {
      final bundle = validBundle().withCachedAccessToken(
        'nearly-dead-token',
        expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 1)),
      );

      expect(bundle.hasValidCachedAccessToken, isFalse);
    });

    test('expired server-reported expiry beats a fresh obtainedAt clock', () {
      final bundle = validBundle().withCachedAccessToken(
        'dead-token-fresh-clock',
        expiresAt: DateTime.now().toUtc().subtract(const Duration(minutes: 5)),
      );

      expect(bundle.hasValidCachedAccessToken, isFalse);
    });

    test('withoutCachedAccessToken drops all token fields', () {
      final bundle = validBundle()
          .withCachedAccessToken(
            'token',
            expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
          )
          .withoutCachedAccessToken();

      expect(bundle.cachedAccessToken, isNull);
      expect(bundle.cachedAccessTokenObtainedAt, isNull);
      expect(bundle.cachedAccessTokenExpiresAt, isNull);
      expect(bundle.hasValidCachedAccessToken, isFalse);
    });

    test('hasOpenIdOfflineGrant requires refresh token and openid scope', () {
      final driveOnly = validBundle().withDriveOfflineGrant(
        refreshToken: 'pkce-refresh-token',
        clientId: 'android-client.apps.googleusercontent.com',
      );
      expect(driveOnly.hasDriveOfflineGrant, isTrue);
      expect(driveOnly.hasOpenIdOfflineGrant, isFalse);

      final withOpenId = validBundle().withDriveOfflineGrant(
        refreshToken: 'pkce-refresh-token',
        clientId: 'android-client.apps.googleusercontent.com',
        scopesGranted: AuthScopes.pkceOfflineGrantScopes,
      );
      expect(withOpenId.hasOpenIdOfflineGrant, isTrue);
      expect(withOpenId.scopesGranted, AuthScopes.pkceOfflineGrantScopes);
    });

    test('hasValidCachedIdToken is false when token absent', () {
      expect(validBundle().hasValidCachedIdToken, isFalse);
    });

    test('hasValidCachedIdToken is true when expiry is in the future', () {
      final bundle = validBundle().withCachedIdToken(
        'id-token-xyz',
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
      );

      expect(bundle.hasValidCachedIdToken, isTrue);
      expect(bundle.cachedIdToken, 'id-token-xyz');
    });

    test('hasValidCachedIdToken is false when expiry is missing', () {
      final bundle = validBundle().withCachedIdToken('id-token-xyz');

      expect(bundle.hasValidCachedIdToken, isFalse);
    });

    test('ID token within the expiry safety margin is treated as dead', () {
      final bundle = validBundle().withCachedIdToken(
        'nearly-dead-id-token',
        expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 1)),
      );

      expect(bundle.hasValidCachedIdToken, isFalse);
    });
  });
}
