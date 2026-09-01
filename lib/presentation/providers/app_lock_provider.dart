import 'dart:async';

import 'package:daftar/core/constants/app_constants.dart';
import 'package:daftar/core/recovery/local_database_reset.dart';
import 'package:daftar/core/utils/security_service.dart';
import 'package:daftar/data/datasources/local/activation_secure_storage_ds.dart';
import 'package:daftar/domain/repositories/settings_repository.dart';
import 'package:daftar/main.dart';
import 'package:daftar/presentation/providers/auth_providers.dart';
import 'package:daftar/presentation/providers/backup_providers.dart';
import 'package:daftar/presentation/providers/core_providers.dart';
import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_lock_provider.g.dart';

/// Whether the app lock overlay should be shown.
enum AppLockStatus {
  /// User may interact with the app.
  unlocked,

  /// Lock screen overlay should block interaction.
  locked,
}

/// Reactive snapshot consumed by routing / lock-screen overlay.
class AppLockState {
  const AppLockState({
    required this.status,
    required this.isAppLockEnabled,
    required this.isBiometricEnabled,
    required this.lockTimeoutSeconds,
    this.backgroundedAt,
    this.lockSession = 0,
  });

  /// Current lock gate.
  final AppLockStatus status;

  /// User preference from app settings.
  final bool isAppLockEnabled;

  /// Whether biometric unlock is allowed when locked.
  final bool isBiometricEnabled;

  /// Seconds in background before [AppLockManager] re-locks on resume.
  final int lockTimeoutSeconds;

  /// UTC timestamp recorded when the app last entered background.
  final DateTime? backgroundedAt;

  /// Increments on each lock() call; keys lock-screen overlay instances.
  final int lockSession;

  /// `true` when the UI should render the lock overlay.
  bool get shouldShowLockOverlay =>
      isAppLockEnabled && status == AppLockStatus.locked;

  AppLockState copyWith({
    AppLockStatus? status,
    bool? isAppLockEnabled,
    bool? isBiometricEnabled,
    int? lockTimeoutSeconds,
    DateTime? backgroundedAt,
    bool clearBackgroundedAt = false,
    int? lockSession,
  }) {
    return AppLockState(
      status: status ?? this.status,
      isAppLockEnabled: isAppLockEnabled ?? this.isAppLockEnabled,
      isBiometricEnabled: isBiometricEnabled ?? this.isBiometricEnabled,
      lockTimeoutSeconds: lockTimeoutSeconds ?? this.lockTimeoutSeconds,
      backgroundedAt: clearBackgroundedAt
          ? null
          : (backgroundedAt ?? this.backgroundedAt),
      lockSession: lockSession ?? this.lockSession,
    );
  }
}

/// Provides the singleton [SecurityService].
@Riverpod(keepAlive: true)
SecurityService securityService(Ref ref) {
  return SecurityService();
}

/// Manages app-lock state, lifecycle resume detection, and unlock flows.
@Riverpod(keepAlive: true)
class AppLockManager extends _$AppLockManager with WidgetsBindingObserver {
  /// Tracks whether the app has entered a background lifecycle state since
  /// the last unlock (guards resume logic for immediate timeout).
  bool _wasInBackground = false;

  /// Whether the OS reports the app in the foreground (`resumed`).
  bool _isForeground = true;

  int _lockSessionCounter = 0;

  /// Whether settings have been hydrated from [appSettingsProvider] at least once.
  bool _settingsHydrated = false;

  @override
  AppLockState build() {
    final service = ref.watch(securityServiceProvider);

    // Listen only — do not watch. Watching would re-run [build] on every settings
    // stream emission (e.g. timeout change) and reset status to locked.
    ref.listen(appSettingsProvider, (previous, next) {
      final data = next.asData?.value;
      if (data == null) {
        return;
      }
      final isFirstHydration =
          !_settingsHydrated && previous?.asData?.value == null;
      _settingsHydrated = true;
      _syncFromSettings(
        data.isAppLockEnabled,
        data.biometricEnabled,
        data.lockTimeoutSeconds,
        lockOnColdStart: isFirstHydration,
      );
    });

    final binding = WidgetsBinding.instance..addObserver(this);
    ref.onDispose(() {
      binding.removeObserver(this);
    });

    final prefs = ref.read(appSettingsProvider).asData?.value;
    if (prefs != null) {
      _settingsHydrated = true;
    }
    final enabled = prefs?.isAppLockEnabled ?? false;
    final biometrics = prefs?.biometricEnabled ?? false;
    final timeout =
        prefs?.lockTimeoutSeconds ?? AppConstants.defaultLockTimeoutSeconds;

    unawaited(_primeInitialLockState(service, enabled));

    if (enabled) {
      _lockSessionCounter++;
    }
    return AppLockState(
      status: enabled ? AppLockStatus.locked : AppLockStatus.unlocked,
      isAppLockEnabled: enabled,
      isBiometricEnabled: biometrics,
      lockTimeoutSeconds: timeout,
      lockSession: enabled ? _lockSessionCounter : 0,
    );
  }

  Future<void> _primeInitialLockState(
    SecurityService service,
    bool enabled,
  ) async {
    if (!enabled) {
      return;
    }
    final hasPin = await service.hasPinConfigured();
    if (!hasPin) {
      return;
    }
    // Do not re-lock if the user already unlocked (e.g. biometric race on
    // cold start). Lock screen security is independent of network auth.
    if (state.status == AppLockStatus.unlocked) {
      return;
    }
    state = state.copyWith(status: AppLockStatus.locked);
  }

  void _syncFromSettings(
    bool enabled,
    bool biometrics,
    int timeoutSeconds, {
    bool lockOnColdStart = false,
  }) {
    final nextStatus = !enabled
        ? AppLockStatus.unlocked
        : (lockOnColdStart ? AppLockStatus.locked : state.status);

    state = state.copyWith(
      isAppLockEnabled: enabled,
      isBiometricEnabled: biometrics,
      lockTimeoutSeconds: timeoutSeconds,
      status: nextStatus,
      clearBackgroundedAt: !enabled,
    );
  }

  /// Marks the app unlocked after successful PIN or biometric auth.
  void unlock() {
    _wasInBackground = false;
    state = state.copyWith(
      status: AppLockStatus.unlocked,
      clearBackgroundedAt: true,
    );
  }

  /// Forces the lock overlay (e.g. manual lock from settings).
  void lock() {
    if (!state.isAppLockEnabled) {
      return;
    }
    _lockSessionCounter++;
    state = state.copyWith(
      status: AppLockStatus.locked,
      lockSession: _lockSessionCounter,
    );
  }

  /// Whether the app is in the foreground and safe to show biometric UI.
  bool get isForeground => _isForeground;

  /// Validates [pin] via [SecurityService] and unlocks on success.
  Future<PinValidationResult> unlockWithPin(String pin) async {
    final result =
        await ref.read(securityServiceProvider).validatePin(pin);
    if (result == PinValidationResult.success) {
      unlock();
    }
    return result;
  }

  /// Runs biometric auth when enabled; unlocks on success.
  ///
  /// Does not depend on Google Sign-In or any network auth provider.
  Future<bool> unlockWithBiometrics() async {
    if (!state.isBiometricEnabled || !_isForeground) {
      return false;
    }
    try {
      final ok = await ref
          .read(securityServiceProvider)
          .authenticateWithBiometrics()
          .timeout(const Duration(seconds: 60));
      if (ok) {
        unlock();
      }
      return ok;
    } on Object {
      return false;
    }
  }

  /// Persists a new PIN and enables app lock in settings.
  Future<bool> configurePin(String pin) async {
    final service = ref.read(securityServiceProvider);
    final stored = await service.setPin(pin);
    if (!stored) {
      return false;
    }
    final result = await ref.read(settingsRepositoryProvider).update(
          const UpdateSettingsParams(
            pinHash: AppConstants.pinConfiguredMarker,
            isAppLockEnabled: true,
          ),
        );
    return result.isRight();
  }

  /// Enables app lock when a PIN is already configured.
  Future<bool> enableAppLock() async {
    final hasPin = await ref.read(securityServiceProvider).hasPinConfigured();
    if (!hasPin) {
      return false;
    }
    final result = await ref.read(settingsRepositoryProvider).update(
          const UpdateSettingsParams(isAppLockEnabled: true),
        );
    return result.fold(
      (_) => false,
      (_) {
        state = state.copyWith(
          isAppLockEnabled: true,
          status: AppLockStatus.unlocked,
          clearBackgroundedAt: true,
        );
        return true;
      },
    );
  }

  /// Disables app lock without removing the stored PIN hash.
  Future<bool> disableAppLock() async {
    final result = await ref.read(settingsRepositoryProvider).update(
          const UpdateSettingsParams(isAppLockEnabled: false),
        );
    return result.fold(
      (_) => false,
      (_) {
        state = state.copyWith(
          isAppLockEnabled: false,
          status: AppLockStatus.unlocked,
          clearBackgroundedAt: true,
        );
        return true;
      },
    );
  }

  /// Replaces the PIN while keeping app lock enabled.
  Future<bool> changePin(String newPin) async {
    final stored = await ref.read(securityServiceProvider).setPin(newPin);
    if (!stored) {
      return false;
    }
    final result = await ref.read(settingsRepositoryProvider).update(
          const UpdateSettingsParams(
            pinHash: AppConstants.pinConfiguredMarker,
            isAppLockEnabled: true,
          ),
        );
    return result.isRight();
  }

  /// Persists biometric unlock preference.
  Future<bool> setBiometricEnabled({required bool enabled}) async {
    final result = await ref.read(settingsRepositoryProvider).update(
          UpdateSettingsParams(biometricEnabled: enabled),
        );
    return result.fold(
      (_) => false,
      (_) {
        state = state.copyWith(isBiometricEnabled: enabled);
        return true;
      },
    );
  }

  /// Requires a successful OS biometric prompt before enabling biometrics.
  Future<bool> enableBiometricWithSystemAuth({
    String localizedReason = 'Authenticate to enable biometric unlock',
  }) async {
    final ok = await ref
        .read(securityServiceProvider)
        .authenticateWithBiometrics(localizedReason: localizedReason);
    if (!ok) {
      return false;
    }
    return setBiometricEnabled(enabled: true);
  }

  /// Persists auto-lock timeout (seconds). No re-auth required.
  Future<bool> setLockTimeoutSeconds(int seconds) async {
    final previous = state.lockTimeoutSeconds;
    state = state.copyWith(lockTimeoutSeconds: seconds);
    final result = await ref.read(settingsRepositoryProvider).update(
          UpdateSettingsParams(lockTimeoutSeconds: seconds),
        );
    return result.fold(
      (_) {
        state = state.copyWith(lockTimeoutSeconds: previous);
        return false;
      },
      (_) => true,
    );
  }

  /// Clears PIN material and disables app lock in settings.
  Future<bool> removePinAndDisableLock() async {
    await ref.read(securityServiceProvider).clearPin();
    final result = await ref.read(settingsRepositoryProvider).update(
          const UpdateSettingsParams(
            clearPinHash: true,
            isAppLockEnabled: false,
            biometricEnabled: false,
          ),
        );
    if (result.isRight()) {
      state = state.copyWith(
        isAppLockEnabled: false,
        isBiometricEnabled: false,
        status: AppLockStatus.unlocked,
        clearBackgroundedAt: true,
      );
      unlock();
    }
    return result.isRight();
  }

  /// Forgot-PIN recovery: wipe secure storage + SQLite, reopen DB in-process,
  /// dismiss lock overlay, and let the caller navigate to backup restore.
  Future<bool> executeForgotPinRecovery() async {
    try {
      await ref.read(securityServiceProvider).clearPin();
      await ActivationSecureStorageDs().clearToken();

      final database = ref.read(appDatabaseProvider);
      final freshDb = await LocalDatabaseReset.softWipeAndReopen(
        databaseToClose: database,
      );
      activeDatabase = freshDb;

      state = const AppLockState(
        status: AppLockStatus.unlocked,
        isAppLockEnabled: false,
        isBiometricEnabled: false,
        lockTimeoutSeconds: AppConstants.defaultLockTimeoutSeconds,
      );

      _invalidateProvidersAfterSoftWipe();
      return true;
    } on Object {
      return false;
    }
  }

  void _invalidateProvidersAfterSoftWipe() {
    appContainer
      ..invalidate(appDatabaseProvider)
      ..invalidate(settingsRepositoryProvider)
      ..invalidate(appSettingsProvider)
      ..invalidate(ledgerRepositoryProvider)
      ..invalidate(contactRepositoryProvider)
      ..invalidate(transactionRepositoryProvider)
      ..invalidate(balanceRepositoryProvider)
      ..invalidate(backupLocalDsProvider)
      ..invalidate(backupRepositoryProvider)
      ..invalidate(backupQueueLocalDsProvider)
      ..invalidate(backupQueueManagerProvider)
      ..invalidate(authStateProvider);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
        // Transient (system UI, transitions) — do not start background timer.
        _isForeground = false;
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _isForeground = false;
        _onBackgrounded();
      case AppLifecycleState.resumed:
        _isForeground = true;
        _onResumed();
      case AppLifecycleState.detached:
        _isForeground = false;
    }
  }

  void _onBackgrounded() {
    if (!state.isAppLockEnabled) {
      return;
    }

    _wasInBackground = true;

    if (state.status == AppLockStatus.locked) {
      return;
    }

    state = state.copyWith(backgroundedAt: DateTime.now().toUtc());

    // Immediate timeout: lock as soon as we leave the foreground.
    if (state.lockTimeoutSeconds <= 0) {
      lock();
    }
  }

  void _onResumed() {
    if (!state.isAppLockEnabled) {
      _wasInBackground = false;
      return;
    }

    if (state.status == AppLockStatus.locked) {
      _wasInBackground = false;
      return;
    }

    final hadBackgroundSession = _wasInBackground;
    _wasInBackground = false;

    // Immediate timeout: any return from background must re-lock.
    if (state.lockTimeoutSeconds <= 0) {
      if (hadBackgroundSession) {
        lock();
      }
      return;
    }

    final backgroundedAt = state.backgroundedAt;
    if (backgroundedAt == null) {
      return;
    }

    final elapsed =
        DateTime.now().toUtc().difference(backgroundedAt).inSeconds;
    if (elapsed >= state.lockTimeoutSeconds) {
      lock();
    } else {
      state = state.copyWith(clearBackgroundedAt: true);
    }
  }

  /// Whether the app should re-lock after the configured background period.
  bool shouldLockAfterBackground(Duration backgroundDuration) {
    if (!state.isAppLockEnabled) {
      return false;
    }
    if (state.lockTimeoutSeconds <= 0) {
      return true;
    }
    return backgroundDuration.inSeconds >= state.lockTimeoutSeconds;
  }
}

/// Read-only convenience provider for lock-overlay visibility.
@riverpod
bool shouldShowAppLockOverlay(Ref ref) {
  return ref.watch(appLockManagerProvider).shouldShowLockOverlay;
}

/// Whether the device can present biometric authentication.
@riverpod
Future<bool> biometricHardwareAvailable(Ref ref) async {
  return ref.read(securityServiceProvider).isDeviceBiometricCapable();
}
