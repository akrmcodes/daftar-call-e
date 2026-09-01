import 'package:daftar/core/services/auth_session_store.dart';
import 'package:daftar/data/datasources/remote/google_auth_ds.dart';
import 'package:daftar/domain/constants/auth_scopes.dart';
import 'package:daftar/domain/value_objects/auth_session_bundle.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, String> vault;
  late AuthSessionStore store;
  late GoogleAuthDs googleAuthDs;

  AuthSessionBundle sampleBundle() => AuthSessionBundle.create(
        googleUserId: 'google-sub-123',
        email: 'merchant@example.com',
        serverClientId: 'web-client-id.apps.googleusercontent.com',
        scopesGranted: AuthScopes.defaultDriveBackupScopes,
        linkedAt: DateTime.utc(2026, 6, 8, 12),
      );

  setUp(() {
    vault = <String, String>{};
    FlutterSecureStoragePlatform.instance =
        TestFlutterSecureStoragePlatform(vault);
    store = AuthSessionStore(storage: const FlutterSecureStorage());
    googleAuthDs = GoogleAuthDs(authSessionStore: store);
  });

  tearDown(() async {
    await googleAuthDs.dispose();
  });

  group('GoogleAuthDs.getAuthenticatedHttpClient headless contract', () {
    test('tryClientFromCachedBundle succeeds with written bundle', () async {
      final bundle =
          sampleBundle().withCachedAccessToken('oauth-access-token-xyz');
      await store.write(bundle);

      final client = await googleAuthDs.tryClientFromCachedBundle();

      expect(client, isNotNull);
    });

    test('rejects headless: false — interactive auth uses signIn() only', () async {
      await store.write(sampleBundle());

      expect(
        () => googleAuthDs.getAuthenticatedHttpClient(headless: false),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
