import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/entities/app_settings.dart';
import 'package:fpdart/fpdart.dart';

/// Contract for application settings persistence.
///
/// Settings are stored as a single-row table. There is always exactly
/// one [AppSettings] instance.
///
/// Implementations must:
/// - Return default [AppSettings] if the row does not exist.
/// - Return [Left(DatabaseFailure)] for persistence errors.
/// - Never delete the settings row.
abstract class SettingsRepository {
  /// Returns the current application settings.
  ///
  /// Returns the default [AppSettings] if no settings have been persisted.
  Future<Either<Failure, AppSettings>> get();

  /// Updates the application settings with the provided values.
  ///
  /// Only non-null fields in [params] are updated; all other fields
  /// remain unchanged.
  ///
  /// Returns the updated [AppSettings] on success.
  /// Returns [Left(DatabaseFailure)] if persistence fails.
  Future<Either<Failure, AppSettings>> update(UpdateSettingsParams params);

  /// Streams the current application settings, emitting on any change.
  ///
  /// Used for reactive UI updates when locale, theme, or other
  /// settings change.
  Stream<AppSettings> watchSettings();
}

/// Parameters for updating application settings.
///
/// All fields are optional. Only non-null fields are applied to the
/// current settings, except [clearGoogleAccount] which forces Google
/// identity fields to null when set to true.
class UpdateSettingsParams {
  const UpdateSettingsParams({
    this.locale,
    this.themeMode,
    this.pinHash,
    this.clearPinHash = false,
    this.isAppLockEnabled,
    this.biometricEnabled,
    this.lockTimeoutSeconds,
    this.defaultCurrency,
    this.lastBackupAt,
    this.analyticsEnabled,
    this.googleAccountId,
    this.googleAccountEmail,
    this.clearGoogleAccount = false,
    this.driveAutoBackupEnabled,
    this.driveAutoBackupInterval,
    this.lastAutoBackupOutcome,
    this.lastAutoBackupFailureCode,
    this.clearLastAutoBackupFailure = false,
    this.isMultiCurrencyEnabled,
    this.isSwipeToDeleteEnabled,
    this.hasSeenOnboarding,
    this.hasSeenAgentFabTip,
    this.ttsMuted,
    this.demoArchitectureHud,
    this.calleAllowDial,
  });
  final String? locale;
  final String? themeMode;
  final String? pinHash;

  /// When true, [pinHash] is cleared regardless of [pinHash] value.
  final bool clearPinHash;

  final bool? isAppLockEnabled;
  final bool? biometricEnabled;
  final int? lockTimeoutSeconds;
  final String? defaultCurrency;
  final DateTime? lastBackupAt;
  final bool? analyticsEnabled;

  /// When non-null, persists the linked Google account id (Drive / identity).
  final String? googleAccountId;

  /// When non-null, persists the linked Google account email.
  final String? googleAccountEmail;

  /// When true, [googleAccountId] and [googleAccountEmail] are cleared regardless
  /// of the other Google fields (sign-out semantics).
  final bool clearGoogleAccount;

  /// When non-null, toggles scheduled Drive auto-backup.
  final bool? driveAutoBackupEnabled;

  /// When non-null, sets cadence (`daily` or `weekly`).
  final String? driveAutoBackupInterval;

  /// When non-null, records the last automatic Drive backup outcome.
  final String? lastAutoBackupOutcome;

  /// When non-null, records a machine-readable auto-backup failure code.
  final String? lastAutoBackupFailureCode;

  /// When true, clears [lastAutoBackupFailureCode] regardless of its value.
  final bool clearLastAutoBackupFailure;

  /// When non-null, toggles per-record currency selection in creation forms.
  final bool? isMultiCurrencyEnabled;

  /// When non-null, toggles swipe-to-delete on contact and transaction lists.
  final bool? isSwipeToDeleteEnabled;

  /// When non-null, records first-run onboarding completion.
  final bool? hasSeenOnboarding;

  /// When non-null, records that the FAB Closing Agent tip was shown.
  final bool? hasSeenAgentFabTip;

  /// When non-null, mutes on-device TTS for confirm and closing report.
  final bool? ttsMuted;

  /// When non-null, shows or hides the contest Architecture HUD overlay.
  final bool? demoArchitectureHud;

  /// When non-null, toggles merchant CALL-E outbound on device.
  final bool? calleAllowDial;
}
