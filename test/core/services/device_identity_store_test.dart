import 'package:daftar/core/constants/app_constants.dart';
import 'package:daftar/core/services/device_identity_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, String> vault;
  late DeviceIdentityStore store;

  setUp(() {
    vault = <String, String>{};
    FlutterSecureStoragePlatform.instance =
        TestFlutterSecureStoragePlatform(vault);
    store = DeviceIdentityStore(storage: const FlutterSecureStorage());
  });

  group('DeviceIdentityStore', () {
    test('returns the same id across repeated reads', () async {
      final first = await store.getOrCreate();
      final second = await store.getOrCreate();
      expect(first, second);
    });

    test('reuses persisted id from secure storage', () async {
      const persisted = '11111111-1111-4111-8111-111111111111';
      vault[AppConstants.deviceIdentityStorageKey] = persisted;
      expect(await store.getOrCreate(), persisted);
    });
  });

  group('DeviceIdentity', () {
    test('initializeForTest exposes current id synchronously', () {
      DeviceIdentity.initializeForTest('device-a');
      expect(DeviceIdentity.current, 'device-a');
    });
  });
}
