import 'package:daftar/core/services/consumed_initial_link_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, String> vault;
  late ConsumedInitialLinkStore store;

  setUp(() {
    vault = <String, String>{};
    FlutterSecureStoragePlatform.instance =
        TestFlutterSecureStoragePlatform(vault);
    store = ConsumedInitialLinkStore(storage: const FlutterSecureStorage());
  });

  group('ConsumedInitialLinkStore', () {
    test('isConsumed returns false when nothing stored', () async {
      final uri = Uri.parse('https://daftar.app/invite/abc123');

      expect(
        await store.isConsumed(uri: uri, token: 'abc123'),
        isFalse,
      );
    });

    test('markConsumed persists uri for cold-start skip', () async {
      final uri = Uri.parse('https://daftar.app/invite/abc123');

      await store.markConsumed(uri: uri, token: 'abc123');

      expect(await store.isConsumed(uri: uri), isTrue);
      expect(await store.isConsumed(token: 'abc123'), isTrue);
      expect(
        await store.isConsumed(
          uri: Uri.parse('https://daftar.app/invite/other'),
        ),
        isFalse,
      );
    });

    test('markConsumed replaces previous consumed entry', () async {
      final first = Uri.parse('https://daftar.app/invite/first');
      final second = Uri.parse('https://daftar.app/invite/second');

      await store.markConsumed(uri: first, token: 'first');
      await store.markConsumed(uri: second, token: 'second');

      expect(await store.isConsumed(uri: first), isFalse);
      expect(await store.isConsumed(uri: second), isTrue);
    });
  });
}
