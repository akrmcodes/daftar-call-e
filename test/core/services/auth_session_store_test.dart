import 'package:daftar/core/constants/app_constants.dart';
import 'package:daftar/core/services/auth_session_store.dart';
import 'package:daftar/domain/constants/auth_scopes.dart';
import 'package:daftar/domain/value_objects/auth_session_bundle.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, String> vault;
  late AuthSessionStore store;

  setUp(() {
    vault = <String, String>{};
    FlutterSecureStoragePlatform.instance =
        TestFlutterSecureStoragePlatform(vault);
    store = AuthSessionStore(storage: const FlutterSecureStorage());
  });

  AuthSessionBundle sampleBundle({
    DateTime? lastSuccessfulSilentAuthAt,
  }) =>
      AuthSessionBundle.create(
        googleUserId: 'google-sub-123',
        email: 'merchant@example.com',
        displayName: 'Merchant',
        photoUrl: 'https://example.com/photo.png',
        serverClientId: 'web-client-id.apps.googleusercontent.com',
        scopesGranted: AuthScopes.defaultDriveBackupScopes,
        linkedAt: DateTime.utc(2026, 6, 8, 12),
        lastSuccessfulSilentAuthAt: lastSuccessfulSilentAuthAt,
      );

  group('AuthSessionStore', () {
    test('read returns null when key is absent', () async {
      expect(await store.read(), isNull);
    });

    test('write then read round-trips all bundle fields', () async {
      final bundle = sampleBundle(
        lastSuccessfulSilentAuthAt: DateTime.utc(2026, 6, 8, 13),
      );

      await store.write(bundle);
      final restored = await store.read();

      expect(restored, bundle);
      expect(vault.containsKey(AppConstants.authSessionStorageKey), isTrue);
    });

    test('delete removes persisted session', () async {
      await store.write(sampleBundle());
      await store.delete();

      expect(await store.read(), isNull);
      expect(vault.containsKey(AppConstants.authSessionStorageKey), isFalse);
    });

    test('updateLastSuccessfulSilentAuthAt updates only silent auth timestamp',
        () async {
      await store.write(sampleBundle());
      final silentAt = DateTime.utc(2026, 6, 8, 18, 30);

      await store.updateLastSuccessfulSilentAuthAt(silentAt);
      final restored = await store.read();

      expect(restored?.lastSuccessfulSilentAuthAt, silentAt);
      expect(restored?.googleUserId, 'google-sub-123');
    });

    test('read deletes corrupt payload and returns null', () async {
      vault[AppConstants.authSessionStorageKey] = '{not-json';

      expect(await store.read(), isNull);
      expect(vault.containsKey(AppConstants.authSessionStorageKey), isFalse);
    });

    test('write round-trips bundle with cached access token in one persist',
        () async {
      final bundle = sampleBundle(
        lastSuccessfulSilentAuthAt: DateTime.utc(2026, 6, 8, 13),
      ).withCachedAccessToken('oauth-access-token');

      await store.write(bundle);
      final restored = await store.read();

      expect(restored, bundle);
      expect(restored?.cachedAccessToken, 'oauth-access-token');
      expect(restored?.hasValidCachedAccessToken, isTrue);
      expect(restored?.lastSuccessfulSilentAuthAt, isNotNull);
    });

    test('updateCachedAccessToken persists token fields', () async {
      await store.write(sampleBundle());

      await store.updateCachedAccessToken('oauth-access-token');
      final restored = await store.read();

      expect(restored?.cachedAccessToken, 'oauth-access-token');
      expect(restored?.cachedAccessTokenObtainedAt, isNotNull);
      expect(restored?.hasValidCachedAccessToken, isTrue);
    });

    test('write round-trips bundle with PKCE offline grant (schema v3)',
        () async {
      final bundle = sampleBundle().withDriveOfflineGrant(
        refreshToken: 'pkce-refresh-token',
        clientId: 'android-client.apps.googleusercontent.com',
      );

      await store.write(bundle);
      final restored = await store.read();

      expect(restored, bundle);
      expect(restored?.driveRefreshToken, 'pkce-refresh-token');
      expect(restored?.hasDriveOfflineGrant, isTrue);
    });

    test('updateDriveOfflineGrant can replace scopesGranted', () async {
      await store.write(sampleBundle());

      await store.updateDriveOfflineGrant(
        refreshToken: 'pkce-refresh-token',
        clientId: 'android-client.apps.googleusercontent.com',
        scopesGranted: AuthScopes.pkceOfflineGrantScopes,
      );
      final restored = await store.read();

      expect(restored?.hasOpenIdOfflineGrant, isTrue);
      expect(restored?.scopesGranted, AuthScopes.pkceOfflineGrantScopes);
    });

    test('updateDriveOfflineGrant persists grant fields', () async {
      await store.write(sampleBundle());

      await store.updateDriveOfflineGrant(
        refreshToken: 'pkce-refresh-token',
        clientId: 'android-client.apps.googleusercontent.com',
      );
      final restored = await store.read();

      expect(restored?.driveRefreshToken, 'pkce-refresh-token');
      expect(
        restored?.driveTokenClientId,
        'android-client.apps.googleusercontent.com',
      );
    });

    test('round-trips server-reported token expiry (schema v4)', () async {
      final expiresAt = DateTime.utc(2026, 6, 10, 14, 30);
      await store.write(sampleBundle());

      await store.updateCachedAccessToken(
        'oauth-access-token',
        expiresAt: expiresAt,
      );
      final restored = await store.read();

      expect(restored?.cachedAccessToken, 'oauth-access-token');
      expect(restored?.cachedAccessTokenExpiresAt, expiresAt);
    });

    test('clearCachedAccessToken drops token fields but keeps the grant',
        () async {
      await store.write(
        sampleBundle()
            .withDriveOfflineGrant(
              refreshToken: 'pkce-refresh-token',
              clientId: 'android-client.apps.googleusercontent.com',
            )
            .withCachedAccessToken('dead-token'),
      );

      await store.clearCachedAccessToken();
      final restored = await store.read();

      expect(restored?.cachedAccessToken, isNull);
      expect(restored?.cachedAccessTokenExpiresAt, isNull);
      expect(restored?.hasDriveOfflineGrant, isTrue);
    });

    test('read accepts schema version 3 without expiry field', () async {
      vault[AppConstants.authSessionStorageKey] =
          '{"schemaVersion":3,"googleUserId":"google-sub-123",'
          '"email":"merchant@example.com",'
          '"serverClientId":"web-client-id.apps.googleusercontent.com",'
          '"scopesGranted":["https://www.googleapis.com/auth/drive.appdata"],'
          '"linkedAt":"2026-06-08T12:00:00.000Z",'
          '"cachedAccessToken":"token",'
          '"driveRefreshToken":"pkce-refresh-token",'
          '"driveTokenClientId":"android-client.apps.googleusercontent.com"}';

      final restored = await store.read();

      expect(restored?.cachedAccessToken, 'token');
      expect(restored?.cachedAccessTokenExpiresAt, isNull);
      expect(restored?.hasDriveOfflineGrant, isTrue);
    });

    test('read accepts schema version 2 without grant fields', () async {
      vault[AppConstants.authSessionStorageKey] =
          '{"schemaVersion":2,"googleUserId":"google-sub-123",'
          '"email":"merchant@example.com",'
          '"serverClientId":"web-client-id.apps.googleusercontent.com",'
          '"scopesGranted":["https://www.googleapis.com/auth/drive.appdata"],'
          '"linkedAt":"2026-06-08T12:00:00.000Z",'
          '"cachedAccessToken":"token"}';

      final restored = await store.read();

      expect(restored?.cachedAccessToken, 'token');
      expect(restored?.driveRefreshToken, isNull);
      expect(restored?.hasDriveOfflineGrant, isFalse);
    });

    test('read accepts schema version 1 without token fields', () async {
      vault[AppConstants.authSessionStorageKey] =
          '{"schemaVersion":1,"googleUserId":"google-sub-123",'
          '"email":"merchant@example.com",'
          '"serverClientId":"web-client-id.apps.googleusercontent.com",'
          '"scopesGranted":["https://www.googleapis.com/auth/drive.appdata"],'
          '"linkedAt":"2026-06-08T12:00:00.000Z"}';

      final restored = await store.read();

      expect(restored?.googleUserId, 'google-sub-123');
      expect(restored?.cachedAccessToken, isNull);
    });

    test('read rejects unsupported schema version', () async {
      vault[AppConstants.authSessionStorageKey] =
          '{"schemaVersion":99,"googleUserId":"x","email":"a@b.com",'
          '"serverClientId":"c","scopesGranted":["s"],'
          '"linkedAt":"2026-06-08T12:00:00.000Z"}';

      expect(await store.read(), isNull);
      expect(vault.containsKey(AppConstants.authSessionStorageKey), isFalse);
    });

    test('read returns null when vault value is empty string', () async {
      vault[AppConstants.authSessionStorageKey] = '';

      expect(await store.read(), isNull);
    });

    test('read wipes vault on JSON array root', () async {
      vault[AppConstants.authSessionStorageKey] = '[]';

      expect(await store.read(), isNull);
      expect(vault.containsKey(AppConstants.authSessionStorageKey), isFalse);
    });

    test('read wipes vault when scopesGranted is not an array', () async {
      vault[AppConstants.authSessionStorageKey] =
          '{"schemaVersion":4,"googleUserId":"id","email":"a@b.com",'
          '"serverClientId":"client","scopesGranted":"not-array",'
          '"linkedAt":"2026-06-08T12:00:00.000Z"}';

      expect(await store.read(), isNull);
      expect(vault.containsKey(AppConstants.authSessionStorageKey), isFalse);
    });

    test('read wipes vault when googleUserId is missing', () async {
      vault[AppConstants.authSessionStorageKey] =
          '{"schemaVersion":4,"email":"a@b.com",'
          '"serverClientId":"client","scopesGranted":["s"],'
          '"linkedAt":"2026-06-08T12:00:00.000Z"}';

      expect(await store.read(), isNull);
      expect(vault.containsKey(AppConstants.authSessionStorageKey), isFalse);
    });

    test('read returns null when PlatformException is thrown on read', () async {
      FlutterSecureStoragePlatform.instance = ThrowingSecureStoragePlatform(
        vault,
        throwOn: {StorageOp.read},
      );
      store = AuthSessionStore(storage: const FlutterSecureStorage());

      expect(await store.read(), isNull);
    });

    test(
        'read returns null when corrupt payload delete also throws PlatformException',
        () async {
      vault[AppConstants.authSessionStorageKey] = '{bad-json';
      FlutterSecureStoragePlatform.instance = ThrowingSecureStoragePlatform(
        vault,
        throwOn: {StorageOp.delete},
      );
      store = AuthSessionStore(storage: const FlutterSecureStorage());

      expect(await store.read(), isNull);
      expect(vault.containsKey(AppConstants.authSessionStorageKey), isTrue);
    });

    test('write propagates PlatformException from secure storage', () async {
      FlutterSecureStoragePlatform.instance = ThrowingSecureStoragePlatform(
        vault,
        throwOn: {StorageOp.write},
      );
      store = AuthSessionStore(storage: const FlutterSecureStorage());

      await expectLater(
        store.write(sampleBundle()),
        throwsA(isA<PlatformException>()),
      );
      expect(vault.containsKey(AppConstants.authSessionStorageKey), isFalse);
    });

    test('updateCachedAccessToken is no-op when bundle is absent', () async {
      await store.updateCachedAccessToken('token');

      expect(vault, isEmpty);
    });

    test('write round-trips cached Google ID token (schema v5)', () async {
      final expiresAt = DateTime.now().toUtc().add(const Duration(hours: 1));
      final bundle = sampleBundle().withCachedIdToken(
        'cached-gsi-id-token',
        expiresAt: expiresAt,
      );

      await store.write(bundle);
      final restored = await store.read();

      expect(restored, bundle);
      expect(restored?.cachedIdToken, 'cached-gsi-id-token');
      expect(restored?.cachedIdTokenExpiresAt, expiresAt);
      expect(restored?.hasValidCachedIdToken, isTrue);
    });

    test('updateCachedIdToken persists token fields', () async {
      await store.write(sampleBundle());
      final expiresAt = DateTime.now().toUtc().add(const Duration(hours: 1));

      await store.updateCachedIdToken(
        'cached-gsi-id-token',
        expiresAt: expiresAt,
      );
      final restored = await store.read();

      expect(restored?.cachedIdToken, 'cached-gsi-id-token');
      expect(restored?.cachedIdTokenExpiresAt, expiresAt);
      expect(restored?.hasValidCachedIdToken, isTrue);
    });

    test('read accepts schema version 4 without ID-token fields', () async {
      vault[AppConstants.authSessionStorageKey] =
          '{"schemaVersion":4,"googleUserId":"google-sub-123",'
          '"email":"merchant@example.com",'
          '"serverClientId":"web-client-id.apps.googleusercontent.com",'
          '"scopesGranted":["https://www.googleapis.com/auth/drive.appdata"],'
          '"linkedAt":"2026-06-08T12:00:00.000Z",'
          '"cachedAccessToken":"token"}';

      final restored = await store.read();

      expect(restored?.cachedAccessToken, 'token');
      expect(restored?.cachedIdToken, isNull);
      expect(restored?.cachedIdTokenExpiresAt, isNull);
      expect(restored?.hasValidCachedIdToken, isFalse);
    });

    test('updateCachedIdToken is no-op when bundle is absent', () async {
      await store.updateCachedIdToken('id-token');

      expect(vault, isEmpty);
    });

    test(
        'partial update round-trip preserves grant after clearing cached token',
        () async {
      await store.write(sampleBundle());
      await store.updateDriveOfflineGrant(
        refreshToken: 'pkce-refresh-token',
        clientId: 'android-client.apps.googleusercontent.com',
      );
      await store.updateCachedAccessToken('oauth-access-token');
      await store.clearCachedAccessToken();

      final restored = await store.read();

      expect(restored?.cachedAccessToken, isNull);
      expect(restored?.hasDriveOfflineGrant, isTrue);
      expect(restored?.driveRefreshToken, 'pkce-refresh-token');
    });
  });
}

enum StorageOp { read, write, delete }

/// In-memory secure storage that can throw [PlatformException] per operation.
class ThrowingSecureStoragePlatform extends FlutterSecureStoragePlatform {
  ThrowingSecureStoragePlatform(
    this.data, {
    this.throwOn = const {},
  });

  final Map<String, String> data;
  final Set<StorageOp> throwOn;

  static final _simulatedFailure = PlatformException(
    code: 'test_os_failure',
    message: 'simulated secure storage failure',
  );

  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async =>
      data.containsKey(key);

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async {
    if (throwOn.contains(StorageOp.delete)) {
      throw _simulatedFailure;
    }
    data.remove(key);
  }

  @override
  Future<void> deleteAll({required Map<String, String> options}) async =>
      data.clear();

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async {
    if (throwOn.contains(StorageOp.read)) {
      throw _simulatedFailure;
    }
    return data[key];
  }

  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async =>
      data;

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async {
    if (throwOn.contains(StorageOp.write)) {
      throw _simulatedFailure;
    }
    data[key] = value;
  }
}
