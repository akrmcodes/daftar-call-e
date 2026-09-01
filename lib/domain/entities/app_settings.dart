import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_settings.freezed.dart';

/// Application-wide user preferences stored as a single-row table.
///
/// This entity represents the global settings for the app. There is
/// exactly one [AppSettings] instance at any time. It is created with
/// defaults on first launch during database migration.
///
/// Fields:
/// - [locale]: Active locale code ('ar' or 'en'). Arabic is default.
/// - [themeMode]: Active theme ('dark', 'light', 'system'). Dark is default.
/// - [pinHash]: Sentinel (`configured`) when a PIN exists. Null otherwise.
///   NOTE: The actual hash is stored in flutter_secure_storage for security.
/// - [isAppLockEnabled]: Whether the app lock overlay is active on resume.
/// - [biometricEnabled]: Whether biometric unlock is enabled.
/// - [lockTimeoutSeconds]: Background duration before re-lock on resume.
/// - [defaultCurrency]: ISO 4217 code for the default currency (e.g., 'YER').
/// - [lastBackupAt]: UTC timestamp of the last successful backup. Null if never backed up.
/// - [analyticsEnabled]: Whether Firebase Analytics collection is active.
///   When false, Firebase collection is disabled per user preference.
/// - [googleAccountId]: Google user id when signed in for Drive backup; null otherwise.
/// - [googleAccountEmail]: Google account email when signed in; null otherwise.
/// - [driveAutoBackupEnabled]: When true, schedules periodic Drive uploads.
/// - [driveAutoBackupInterval]: Storage key for cadence (`daily` or `weekly`).
/// - [lastAutoBackupOutcome]: Result of the last scheduled Drive backup.
/// - [lastAutoBackupFailureCode]: Machine-readable code when outcome is failed.
/// - [isMultiCurrencyEnabled]: When false, creation flows use [defaultCurrency]
///   only; existing multi-currency records remain display-only.
/// - [isSwipeToDeleteEnabled]: When true, list tiles allow swipe-to-delete.
///   When false, deletion is only available via the trailing action menu.
/// - [hasSeenOnboarding]: When true, the first-run walkthrough has completed.
/// - [hasSeenAgentFabTip]: When true, the FAB tap/hold coach has been shown.
/// - [ttsMuted]: When true, skip on-device TTS for confirm and closing report.
/// - [demoArchitectureHud]: When true, show the contest Architecture HUD overlay.
@freezed
abstract class AppSettings with _$AppSettings {
  const factory AppSettings({
    @Default('ar') String locale,
    @Default('system') String themeMode,
    String? pinHash,
    @Default(false) bool isAppLockEnabled,
    @Default(false) bool biometricEnabled,
    @Default(60) int lockTimeoutSeconds,
    @Default('YER') String defaultCurrency,
    DateTime? lastBackupAt,
    @Default(true) bool analyticsEnabled,
    String? googleAccountId,
    String? googleAccountEmail,
    @Default(false) bool driveAutoBackupEnabled,
    @Default('daily') String driveAutoBackupInterval,
    String? lastAutoBackupOutcome,
    String? lastAutoBackupFailureCode,
    @Default(false) bool isMultiCurrencyEnabled,
    @Default(false) bool isSwipeToDeleteEnabled,
    @Default(false) bool hasSeenOnboarding,
    @Default(false) bool hasSeenAgentFabTip,
    @Default(false) bool ttsMuted,
    @Default(false) bool demoArchitectureHud,
  }) = _AppSettings;
}
