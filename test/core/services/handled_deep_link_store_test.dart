import 'package:daftar/core/services/handled_deep_link_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, String> vault;
  late HandledDeepLinkStore store;

  setUp(() {
    vault = <String, String>{};
    FlutterSecureStoragePlatform.instance =
        TestFlutterSecureStoragePlatform(vault);
    store = HandledDeepLinkStore(storage: const FlutterSecureStorage());
  });

  group('HandledDeepLinkStore', () {
    test('isHandled returns false for unknown token', () async {
      expect(await store.isHandled('abcdefghijklmnopqrstuvwxyz012345'), isFalse);
    });

    test('markHandled persists token for skip on cold start', () async {
      const token = 'abcdefghijklmnopqrstuvwxyz012345';

      await store.markHandled(token);

      expect(await store.isHandled(token), isTrue);
      expect(await store.isHandled('other-token'), isFalse);
    });

    test('markHandled trims whitespace', () async {
      const token = 'abcdefghijklmnopqrstuvwxyz012345';

      await store.markHandled('  $token  ');

      expect(await store.isHandled(token), isTrue);
    });
  });
}
