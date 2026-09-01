import 'package:daftar/core/services/deferred_install_attribution_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, String> vault;
  late DeferredInstallAttributionStore store;

  setUp(() {
    vault = <String, String>{};
    FlutterSecureStoragePlatform.instance =
        TestFlutterSecureStoragePlatform(vault);
    store = DeferredInstallAttributionStore(
      storage: const FlutterSecureStorage(),
    );
  });

  group('DeferredInstallAttributionStore', () {
    test('captureFromReferrerString parses utm_content', () async {
      const token = 'abcdefghijklmnopqrstuvwxyz012345';
      await store.captureFromReferrerString(
        'utm_source=daftar&utm_medium=deep_link&utm_content=$token',
      );

      final pending = await store.takePendingToken();
      expect(pending, token);
    });

    test('takePendingToken is one-shot', () async {
      const token = 'abcdefghijklmnopqrstuvwxyz012345';
      await store.captureFromReferrerString('utm_content=$token');

      expect(await store.takePendingToken(), token);
      expect(await store.takePendingToken(), isNull);
    });
  });
}
