import 'package:daftar/core/services/firebase_analytics_consent.dart';
import 'package:daftar/domain/repositories/settings_repository.dart';
import 'package:daftar/presentation/providers/core_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'settings_preferences_provider.g.dart';

/// Persists user-facing settings mutations (currency, analytics, etc.).
@riverpod
class SettingsPreferences extends _$SettingsPreferences {
  @override
  void build() {}

  /// Updates the default currency ISO code.
  Future<bool> setDefaultCurrency(String code) async {
    final result = await ref
        .read(settingsRepositoryProvider)
        .update(
          UpdateSettingsParams(defaultCurrency: code),
        );
    return result.isRight();
  }

  /// Persists the analytics preference then mirrors the value to the
  /// Firebase Analytics SDK (fail-soft if Firebase is unavailable).
  Future<bool> setAnalyticsEnabled({required bool enabled}) async {
    final result = await ref
        .read(settingsRepositoryProvider)
        .update(
          UpdateSettingsParams(analyticsEnabled: enabled),
        );
    if (result.isRight()) {
      await FirebaseAnalyticsConsent.apply(enabled: enabled);
    }
    return result.isRight();
  }

  /// Toggles per-record currency selection in creation forms.
  Future<bool> setMultiCurrencyEnabled({required bool enabled}) async {
    final result = await ref
        .read(settingsRepositoryProvider)
        .update(
          UpdateSettingsParams(isMultiCurrencyEnabled: enabled),
        );
    return result.isRight();
  }

  /// Toggles swipe-to-delete on contact and transaction list tiles.
  Future<bool> setSwipeToDeleteEnabled({required bool enabled}) async {
    final result = await ref
        .read(settingsRepositoryProvider)
        .update(
          UpdateSettingsParams(isSwipeToDeleteEnabled: enabled),
        );
    return result.isRight();
  }

  /// Mutes on-device TTS for confirm read-back and the closing report.
  Future<bool> setTtsMuted({required bool muted}) async {
    final result = await ref
        .read(settingsRepositoryProvider)
        .update(
          UpdateSettingsParams(ttsMuted: muted),
        );
    return result.isRight();
  }

  /// Shows or hides the contest Architecture HUD overlay.
  Future<bool> setDemoArchitectureHud({required bool enabled}) async {
    final result = await ref
        .read(setDemoArchitectureHudUseCaseProvider)
        .execute(enabled: enabled);
    return result.isRight();
  }
}
