import 'package:daftar/core/services/background_backup_flight_lock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('BackgroundBackupFlightLock', () {
    test('tryAcquire succeeds when unlocked', () async {
      final owner = await BackgroundBackupFlightLock.tryAcquire();
      expect(owner, isNotNull);
      expect(await BackgroundBackupFlightLock.isHeld(), isTrue);
      await BackgroundBackupFlightLock.release(owner!);
      expect(await BackgroundBackupFlightLock.isHeld(), isFalse);
    });

    test('second acquire fails while first lock is held', () async {
      final first = await BackgroundBackupFlightLock.tryAcquire();
      expect(first, isNotNull);

      final second = await BackgroundBackupFlightLock.tryAcquire();
      expect(second, isNull);

      await BackgroundBackupFlightLock.release(first!);
      final third = await BackgroundBackupFlightLock.tryAcquire();
      expect(third, isNotNull);
      await BackgroundBackupFlightLock.release(third!);
    });

    test('release ignores mismatched owner', () async {
      final owner = await BackgroundBackupFlightLock.tryAcquire();
      await BackgroundBackupFlightLock.release('not-the-owner');
      expect(await BackgroundBackupFlightLock.isHeld(), isTrue);
      await BackgroundBackupFlightLock.release(owner!);
      expect(await BackgroundBackupFlightLock.isHeld(), isFalse);
    });
  });
}
