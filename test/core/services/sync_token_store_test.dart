import 'package:daftar/core/constants/app_constants.dart';
import 'package:daftar/core/services/sync_token_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, String> vault;
  late SyncTokenStore store;

  setUp(() {
    vault = <String, String>{};
    FlutterSecureStoragePlatform.instance =
        TestFlutterSecureStoragePlatform(vault);
    store = SyncTokenStore(storage: const FlutterSecureStorage());
  });

  SyncTokenBundle sampleBundle({
    DateTime? obtainedAt,
    int expiresIn = 3600,
  }) =>
      SyncTokenBundle(
        syncToken: 'jwt-token',
        workspaceId: 'ws-uuid',
        role: 'owner',
        obtainedAt: obtainedAt ?? DateTime.now().toUtc(),
        expiresIn: expiresIn,
      );

  group('SyncTokenStore', () {
    test('read returns null when key is absent', () async {
      expect(await store.read(), isNull);
    });

    test('write then read round-trips bundle fields', () async {
      final bundle = sampleBundle(
        obtainedAt: DateTime.utc(2026, 7, 4, 12),
      );

      await store.write(bundle);
      final restored = await store.read();

      expect(restored?.syncToken, bundle.syncToken);
      expect(restored?.workspaceId, bundle.workspaceId);
      expect(restored?.role, bundle.role);
      expect(restored?.expiresIn, bundle.expiresIn);
      expect(vault.containsKey(AppConstants.syncTokenStorageKey), isTrue);
    });

    test('write also persists last-known membership', () async {
      await store.write(
        SyncTokenBundle(
          syncToken: 'jwt',
          workspaceId: 'ws-1',
          role: 'editor',
          obtainedAt: DateTime.utc(2026, 8, 2),
          expiresIn: 3600,
          identityHash: 'hash-abc',
        ),
      );

      final membership = await store.readLastKnownMembership();
      expect(membership?.workspaceId, 'ws-1');
      expect(membership?.role, 'editor');
      expect(membership?.identityHash, 'hash-abc');
    });

    test('delete removes sync token and last-known membership', () async {
      await store.write(sampleBundle());
      await store.delete();

      expect(await store.read(), isNull);
      expect(await store.readLastKnownMembership(), isNull);
      expect(vault.containsKey(AppConstants.syncTokenStorageKey), isFalse);
      expect(vault.containsKey(AppConstants.syncMembershipStorageKey), isFalse);
    });

    test('read wipes corrupt payload and returns null', () async {
      vault[AppConstants.syncTokenStorageKey] = 'not-json';

      expect(await store.read(), isNull);
      expect(vault.containsKey(AppConstants.syncTokenStorageKey), isFalse);
    });
  });

  group('SyncTokenBundle', () {
    test('isExpired is false inside safety margin window', () {
      final bundle = sampleBundle(
        obtainedAt: DateTime.now().toUtc(),
      );
      expect(bundle.isExpired, isFalse);
      expect(bundle.isValid, isTrue);
    });

    test('isExpired is true after TTL minus safety margin', () {
      final bundle = sampleBundle(
        obtainedAt: DateTime.now().toUtc().subtract(const Duration(hours: 1)),
      );
      expect(bundle.isExpired, isTrue);
      expect(bundle.isValid, isFalse);
    });
  });
}
