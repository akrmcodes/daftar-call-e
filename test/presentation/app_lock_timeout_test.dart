import 'package:daftar/presentation/providers/app_lock_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppLockState.shouldLockAfterBackground semantics', () {
    late _TimeoutProbe probe;

    setUp(() {
      probe = _TimeoutProbe();
    });

    test('app lock disabled never requires re-lock', () {
      const state = AppLockState(
        status: AppLockStatus.unlocked,
        isAppLockEnabled: false,
        isBiometricEnabled: false,
        lockTimeoutSeconds: 60,
      );
      expect(probe.shouldLock(state, const Duration(hours: 1)), isFalse);
    });

    test('immediate timeout (0s) locks after any background duration', () {
      const state = AppLockState(
        status: AppLockStatus.unlocked,
        isAppLockEnabled: true,
        isBiometricEnabled: false,
        lockTimeoutSeconds: 0,
      );
      expect(probe.shouldLock(state, Duration.zero), isTrue);
      expect(probe.shouldLock(state, const Duration(seconds: 1)), isTrue);
      expect(probe.shouldLock(state, const Duration(minutes: 5)), isTrue);
    });

    test('60s timeout does not lock before threshold', () {
      const state = AppLockState(
        status: AppLockStatus.unlocked,
        isAppLockEnabled: true,
        isBiometricEnabled: false,
        lockTimeoutSeconds: 60,
      );
      expect(probe.shouldLock(state, Duration.zero), isFalse);
      expect(probe.shouldLock(state, const Duration(seconds: 59)), isFalse);
      expect(probe.shouldLock(state, const Duration(seconds: 60)), isTrue);
      expect(probe.shouldLock(state, const Duration(seconds: 61)), isTrue);
    });

    test('300s timeout locks exactly at boundary', () {
      const state = AppLockState(
        status: AppLockStatus.unlocked,
        isAppLockEnabled: true,
        isBiometricEnabled: false,
        lockTimeoutSeconds: 300,
      );
      expect(probe.shouldLock(state, const Duration(seconds: 299)), isFalse);
      expect(probe.shouldLock(state, const Duration(seconds: 300)), isTrue);
    });
  });
}

/// Mirrors [AppLockManager.shouldLockAfterBackground] for pure unit tests.
class _TimeoutProbe {
  bool shouldLock(AppLockState state, Duration backgroundDuration) {
    if (!state.isAppLockEnabled) {
      return false;
    }
    if (state.lockTimeoutSeconds <= 0) {
      return true;
    }
    return backgroundDuration.inSeconds >= state.lockTimeoutSeconds;
  }
}
