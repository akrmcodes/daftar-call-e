import 'package:daftar/core/services/pending_cloud_sync_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PendingCloudSyncStore', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('hasPending returns false when unset', () async {
      expect(await PendingCloudSyncStore.hasPending(), isFalse);
    });

    test('setPending(true) persists across reads', () async {
      await PendingCloudSyncStore.setPending(value: true);

      expect(await PendingCloudSyncStore.hasPending(), isTrue);
    });

    test('clear resets pending flag', () async {
      await PendingCloudSyncStore.setPending(value: true);
      await PendingCloudSyncStore.clear();

      expect(await PendingCloudSyncStore.hasPending(), isFalse);
    });
  });
}
