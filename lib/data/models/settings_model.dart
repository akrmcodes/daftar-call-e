import 'package:daftar/core/constants/db_constants.dart';
import 'package:daftar/data/datasources/local/drift_database.dart' as db;
import 'package:daftar/domain/entities/app_settings.dart' as domain;
import 'package:drift/drift.dart';

/// Data-layer representation of the singleton app settings row.
class SettingsModel {
  /// Creates a settings model.
  const SettingsModel({
    required this.id,
    required this.locale,
    required this.themeMode,
    required this.isAppLockEnabled,
    required this.biometricEnabled,
    required this.lockTimeoutSeconds,
    required this.defaultCurrency,
    required this.analyticsEnabled,
    this.pinHash,
    this.lastBackupAt,
    this.googleAccountId,
    this.googleAccountEmail,
    this.driveAutoBackupEnabled = false,
    this.driveAutoBackupInterval = 'daily',
    this.lastAutoBackupOutcome,
    this.lastAutoBackupFailureCode,
    this.isMultiCurrencyEnabled = false,
    this.isSwipeToDeleteEnabled = false,
    this.hasSeenOnboarding = false,
    this.hasSeenAgentFabTip = false,
    this.ttsMuted = false,
    this.demoArchitectureHud = false,
    this.syncPullWatermarkOpSeq = 0,
  });

  /// Creates a model from the domain entity.
  factory SettingsModel.fromDomain(
    domain.AppSettings settings, {
    int id = DbConstants.appSettingsId,
  }) {
    return SettingsModel(
      id: id,
      locale: settings.locale,
      themeMode: settings.themeMode,
      pinHash: settings.pinHash,
      isAppLockEnabled: settings.isAppLockEnabled,
      biometricEnabled: settings.biometricEnabled,
      lockTimeoutSeconds: settings.lockTimeoutSeconds,
      defaultCurrency: settings.defaultCurrency,
      lastBackupAt: settings.lastBackupAt,
      analyticsEnabled: settings.analyticsEnabled,
      googleAccountId: settings.googleAccountId,
      googleAccountEmail: settings.googleAccountEmail,
      driveAutoBackupEnabled: settings.driveAutoBackupEnabled,
      driveAutoBackupInterval: settings.driveAutoBackupInterval,
      lastAutoBackupOutcome: settings.lastAutoBackupOutcome,
      lastAutoBackupFailureCode: settings.lastAutoBackupFailureCode,
      isMultiCurrencyEnabled: settings.isMultiCurrencyEnabled,
      isSwipeToDeleteEnabled: settings.isSwipeToDeleteEnabled,
      hasSeenOnboarding: settings.hasSeenOnboarding,
      hasSeenAgentFabTip: settings.hasSeenAgentFabTip,
      ttsMuted: settings.ttsMuted,
      demoArchitectureHud: settings.demoArchitectureHud,
    );
  }

  /// Singleton row ID.
  final int id;

  /// Active locale code.
  final String locale;

  /// Active theme mode.
  final String themeMode;

  /// Optional secure storage hash reference.
  final String? pinHash;

  /// Whether app lock is enabled.
  final bool isAppLockEnabled;

  /// Whether biometric unlock is enabled.
  final bool biometricEnabled;

  /// Background seconds before re-lock on resume.
  final int lockTimeoutSeconds;

  /// Default currency code.
  final String defaultCurrency;

  /// Last successful backup timestamp.
  final DateTime? lastBackupAt;

  /// Whether analytics collection is enabled.
  final bool analyticsEnabled;

  /// Linked Google account id for Drive backup.
  final String? googleAccountId;

  /// Linked Google account email.
  final String? googleAccountEmail;

  /// Whether Drive auto-backup is enabled.
  final bool driveAutoBackupEnabled;

  /// Drive auto-backup cadence (`daily` or `weekly`).
  final String driveAutoBackupInterval;

  /// Outcome of the last automatic Drive backup.
  final String? lastAutoBackupOutcome;

  /// Machine-readable failure code from the last automatic Drive backup.
  final String? lastAutoBackupFailureCode;

  /// Whether per-record currency selection is enabled in creation forms.
  final bool isMultiCurrencyEnabled;

  /// Whether swipe-to-delete is enabled on list tiles.
  final bool isSwipeToDeleteEnabled;

  /// Whether the first-run onboarding walkthrough has been completed.
  final bool hasSeenOnboarding;

  /// Whether the Closing Agent FAB first-run tip has been shown.
  final bool hasSeenAgentFabTip;

  /// When true, skip on-device TTS for confirm read-back and closing report.
  final bool ttsMuted;

  /// When true, show the contest Architecture HUD overlay.
  final bool demoArchitectureHud;

  /// Device-local pull cursor. Sync bookkeeping — not a user preference and
  /// never mapped into [domain.AppSettings].
  final int syncPullWatermarkOpSeq;

  /// Converts this model back to the domain entity.
  domain.AppSettings toDomain() {
    return domain.AppSettings(
      locale: locale,
      themeMode: themeMode,
      pinHash: pinHash,
      isAppLockEnabled: isAppLockEnabled,
      biometricEnabled: biometricEnabled,
      lockTimeoutSeconds: lockTimeoutSeconds,
      defaultCurrency: defaultCurrency,
      lastBackupAt: lastBackupAt,
      analyticsEnabled: analyticsEnabled,
      googleAccountId: googleAccountId,
      googleAccountEmail: googleAccountEmail,
      driveAutoBackupEnabled: driveAutoBackupEnabled,
      driveAutoBackupInterval: driveAutoBackupInterval,
      lastAutoBackupOutcome: lastAutoBackupOutcome,
      lastAutoBackupFailureCode: lastAutoBackupFailureCode,
      isMultiCurrencyEnabled: isMultiCurrencyEnabled,
      isSwipeToDeleteEnabled: isSwipeToDeleteEnabled,
      hasSeenOnboarding: hasSeenOnboarding,
      hasSeenAgentFabTip: hasSeenAgentFabTip,
      ttsMuted: ttsMuted,
      demoArchitectureHud: demoArchitectureHud,
    );
  }

  /// Converts this model to the generated Drift row.
  db.AppSettingsTableData toDrift() {
    return db.AppSettingsTableData(
      id: id,
      locale: locale,
      themeMode: themeMode,
      pinHash: pinHash,
      isAppLockEnabled: isAppLockEnabled,
      biometricEnabled: biometricEnabled,
      lockTimeoutSeconds: lockTimeoutSeconds,
      defaultCurrency: defaultCurrency,
      lastBackupAt: lastBackupAt,
      analyticsEnabled: analyticsEnabled,
      googleAccountId: googleAccountId,
      googleAccountEmail: googleAccountEmail,
      driveAutoBackupEnabled: driveAutoBackupEnabled,
      driveAutoBackupInterval: driveAutoBackupInterval,
      lastAutoBackupOutcome: lastAutoBackupOutcome,
      lastAutoBackupFailureCode: lastAutoBackupFailureCode,
      isMultiCurrencyEnabled: isMultiCurrencyEnabled,
      isSwipeToDeleteEnabled: isSwipeToDeleteEnabled,
      hasSeenOnboarding: hasSeenOnboarding,
      hasSeenAgentFabTip: hasSeenAgentFabTip,
      ttsMuted: ttsMuted,
      demoArchitectureHud: demoArchitectureHud,
      syncPullWatermarkOpSeq: syncPullWatermarkOpSeq,
    );
  }

  /// Preference-only companion — omits [syncPullWatermarkOpSeq] so settings
  /// upserts never rewind the merge engine's pull cursor.
  db.AppSettingsTableCompanion toCompanion() {
    return db.AppSettingsTableCompanion(
      id: Value(id),
      locale: Value(locale),
      themeMode: Value(themeMode),
      pinHash: Value(pinHash),
      isAppLockEnabled: Value(isAppLockEnabled),
      biometricEnabled: Value(biometricEnabled),
      lockTimeoutSeconds: Value(lockTimeoutSeconds),
      defaultCurrency: Value(defaultCurrency),
      lastBackupAt: Value(lastBackupAt),
      analyticsEnabled: Value(analyticsEnabled),
      googleAccountId: Value(googleAccountId),
      googleAccountEmail: Value(googleAccountEmail),
      driveAutoBackupEnabled: Value(driveAutoBackupEnabled),
      driveAutoBackupInterval: Value(driveAutoBackupInterval),
      lastAutoBackupOutcome: Value(lastAutoBackupOutcome),
      lastAutoBackupFailureCode: Value(lastAutoBackupFailureCode),
      isMultiCurrencyEnabled: Value(isMultiCurrencyEnabled),
      isSwipeToDeleteEnabled: Value(isSwipeToDeleteEnabled),
      hasSeenOnboarding: Value(hasSeenOnboarding),
      hasSeenAgentFabTip: Value(hasSeenAgentFabTip),
      ttsMuted: Value(ttsMuted),
      demoArchitectureHud: Value(demoArchitectureHud),
    );
  }
}
