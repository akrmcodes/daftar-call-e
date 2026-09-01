import 'package:daftar/data/datasources/local/drift_database.dart' as db;
import 'package:daftar/data/models/settings_model.dart';
import 'package:daftar/domain/entities/app_settings.dart' as domain;

/// Seamless conversions for settings domain, data, and Drift types.
extension SettingsDomainMapper on domain.AppSettings {
  /// Converts a domain settings object to the data-layer model.
  SettingsModel toModel() => SettingsModel.fromDomain(this);

  /// Converts a domain settings object directly to a Drift row.
  ///
  /// Preference columns only via [SettingsModel.toCompanion] on write paths;
  /// the full row here carries a zero watermark placeholder because the
  /// domain entity does not own sync cursors.
  db.AppSettingsTableData toDrift() => toModel().toDrift();

  /// Converts a domain settings object to a Drift companion.
  ///
  /// Uses the preference-only companion so sync cursors stay untouched.
  db.AppSettingsTableCompanion toCompanion() => toModel().toCompanion();
}

/// Seamless conversions for generated Drift settings rows.
extension SettingsDriftMapper on db.AppSettingsTableData {
  /// Converts a Drift settings row to the data-layer model.
  SettingsModel toModel() {
    return SettingsModel(
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

  /// Converts a Drift settings row back to the domain entity.
  domain.AppSettings toDomain() => toModel().toDomain();
}

/// Seamless conversions for generated Drift settings companions.
extension SettingsCompanionMapper on db.AppSettingsTableCompanion {
  /// Converts a Drift settings companion to the data-layer model.
  SettingsModel toModel() {
    return SettingsModel(
      id: id.value,
      locale: locale.value,
      themeMode: themeMode.value,
      pinHash: pinHash.present ? pinHash.value : null,
      isAppLockEnabled: isAppLockEnabled.value,
      biometricEnabled: biometricEnabled.value,
      lockTimeoutSeconds: lockTimeoutSeconds.value,
      defaultCurrency: defaultCurrency.value,
      lastBackupAt: lastBackupAt.present ? lastBackupAt.value : null,
      analyticsEnabled: analyticsEnabled.value,
      googleAccountId: googleAccountId.present ? googleAccountId.value : null,
      googleAccountEmail: googleAccountEmail.present
          ? googleAccountEmail.value
          : null,
      driveAutoBackupEnabled: driveAutoBackupEnabled.value,
      driveAutoBackupInterval: driveAutoBackupInterval.value,
      lastAutoBackupOutcome: lastAutoBackupOutcome.present
          ? lastAutoBackupOutcome.value
          : null,
      lastAutoBackupFailureCode: lastAutoBackupFailureCode.present
          ? lastAutoBackupFailureCode.value
          : null,
      isMultiCurrencyEnabled: isMultiCurrencyEnabled.value,
      isSwipeToDeleteEnabled: isSwipeToDeleteEnabled.value,
      hasSeenOnboarding: hasSeenOnboarding.value,
      hasSeenAgentFabTip: hasSeenAgentFabTip.value,
      ttsMuted: ttsMuted.value,
      demoArchitectureHud: demoArchitectureHud.value,
      syncPullWatermarkOpSeq: syncPullWatermarkOpSeq.present
          ? syncPullWatermarkOpSeq.value
          : 0,
    );
  }

  /// Converts a Drift settings companion back to the domain entity.
  domain.AppSettings toDomain() => toModel().toDomain();

  /// Converts a Drift settings companion to a Drift row.
  db.AppSettingsTableData toDrift() => toModel().toDrift();
}
