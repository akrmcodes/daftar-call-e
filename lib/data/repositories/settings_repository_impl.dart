import 'package:daftar/core/constants/db_constants.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/utils/uuid_util.dart';
import 'package:daftar/data/datasources/local/audit_log_local_ds.dart';
import 'package:daftar/data/datasources/local/drift_database.dart' as db;
import 'package:daftar/data/datasources/local/settings_local_ds.dart';
import 'package:daftar/data/mappers/settings_mapper.dart';
import 'package:daftar/data/models/audit_log_model.dart';
import 'package:daftar/data/models/settings_model.dart';
import 'package:daftar/data/repositories/repository_utils.dart';
import 'package:daftar/domain/entities/app_settings.dart';
import 'package:daftar/domain/repositories/settings_repository.dart';
import 'package:fpdart/fpdart.dart';

/// Drift-backed implementation of [SettingsRepository].
class SettingsRepositoryImpl implements SettingsRepository {
  /// Creates a settings repository implementation.
  SettingsRepositoryImpl({
    required SettingsLocalDataSource settingsLocalDataSource,
    required AuditLogLocalDataSource auditLogLocalDataSource,
  }) : _settingsLocalDataSource = settingsLocalDataSource,
       _auditLogLocalDataSource = auditLogLocalDataSource;

  final SettingsLocalDataSource _settingsLocalDataSource;
  final AuditLogLocalDataSource _auditLogLocalDataSource;

  db.AppDatabase get _database => _settingsLocalDataSource.database;

  @override
  Future<Either<Failure, AppSettings>> get() async {
    try {
      final row = await _database
          .select(_database.appSettingsTable)
          .getSingleOrNull();
      if (row == null) {
        return const Right(AppSettings());
      }

      return Right(row.toModel().toDomain());
    } on Object catch (error) {
      return Left(databaseFailure(error));
    }
  }

  @override
  Stream<AppSettings> watchSettings() {
    return _database.select(_database.appSettingsTable).watch().map((rows) {
      if (rows.isEmpty) {
        return const AppSettings();
      }

      return rows.first.toModel().toDomain();
    });
  }

  @override
  Future<Either<Failure, AppSettings>> update(
    UpdateSettingsParams params,
  ) async {
    try {
      final existingRow = await _database
          .select(_database.appSettingsTable)
          .getSingleOrNull();
      final existing = existingRow == null
          ? const AppSettings()
          : existingRow.toModel().toDomain();
      late final bool driveAutoBackupEnabled;
      late final String driveAutoBackupInterval;
      if (params.clearGoogleAccount) {
        driveAutoBackupEnabled = false;
        driveAutoBackupInterval = 'daily';
      } else {
        driveAutoBackupEnabled =
            params.driveAutoBackupEnabled ?? existing.driveAutoBackupEnabled;
        driveAutoBackupInterval =
            params.driveAutoBackupInterval ?? existing.driveAutoBackupInterval;
      }
      final updated = existing.copyWith(
        locale: params.locale ?? existing.locale,
        themeMode: params.themeMode ?? existing.themeMode,
        pinHash: params.clearPinHash
            ? null
            : (params.pinHash ?? existing.pinHash),
        isAppLockEnabled: params.isAppLockEnabled ?? existing.isAppLockEnabled,
        biometricEnabled: params.biometricEnabled ?? existing.biometricEnabled,
        lockTimeoutSeconds:
            params.lockTimeoutSeconds ?? existing.lockTimeoutSeconds,
        defaultCurrency: params.defaultCurrency ?? existing.defaultCurrency,
        lastBackupAt: params.lastBackupAt ?? existing.lastBackupAt,
        analyticsEnabled: params.analyticsEnabled ?? existing.analyticsEnabled,
        googleAccountId: params.clearGoogleAccount
            ? null
            : (params.googleAccountId ?? existing.googleAccountId),
        googleAccountEmail: params.clearGoogleAccount
            ? null
            : (params.googleAccountEmail ?? existing.googleAccountEmail),
        driveAutoBackupEnabled: driveAutoBackupEnabled,
        driveAutoBackupInterval: driveAutoBackupInterval,
        lastAutoBackupOutcome:
            params.lastAutoBackupOutcome ??
            (params.clearLastAutoBackupFailure
                ? 'success'
                : existing.lastAutoBackupOutcome),
        lastAutoBackupFailureCode: params.clearLastAutoBackupFailure
            ? null
            : (params.lastAutoBackupFailureCode ??
                  existing.lastAutoBackupFailureCode),
        isMultiCurrencyEnabled:
            params.isMultiCurrencyEnabled ?? existing.isMultiCurrencyEnabled,
        isSwipeToDeleteEnabled:
            params.isSwipeToDeleteEnabled ?? existing.isSwipeToDeleteEnabled,
        hasSeenOnboarding:
            params.hasSeenOnboarding ?? existing.hasSeenOnboarding,
        hasSeenAgentFabTip:
            params.hasSeenAgentFabTip ?? existing.hasSeenAgentFabTip,
        ttsMuted: params.ttsMuted ?? existing.ttsMuted,
        demoArchitectureHud:
            params.demoArchitectureHud ?? existing.demoArchitectureHud,
        calleAllowDial: params.calleAllowDial ?? existing.calleAllowDial,
      );

      if (params.clearGoogleAccount) {
        await _settingsLocalDataSource.clearGoogleAccountFields();
      }

      await _settingsLocalDataSource.updateSettings(
        SettingsModel.fromDomain(updated),
      );
      await _appendAuditLog(
        entityType: 'settings',
        entityId: DbConstants.appSettingsId.toString(),
        action: 'UPDATE',
        payload: encodePayload({
          'locale': updated.locale,
          'themeMode': updated.themeMode,
          'isAppLockEnabled': updated.isAppLockEnabled,
          'biometricEnabled': updated.biometricEnabled,
          'lockTimeoutSeconds': updated.lockTimeoutSeconds,
          'defaultCurrency': updated.defaultCurrency,
          'analyticsEnabled': updated.analyticsEnabled,
          'isMultiCurrencyEnabled': updated.isMultiCurrencyEnabled,
          'isSwipeToDeleteEnabled': updated.isSwipeToDeleteEnabled,
          'hasSeenOnboarding': updated.hasSeenOnboarding,
          'hasSeenAgentFabTip': updated.hasSeenAgentFabTip,
          'ttsMuted': updated.ttsMuted,
          'demoArchitectureHud': updated.demoArchitectureHud,
          'calleAllowDial': updated.calleAllowDial,
        }),
      );

      return Right(updated);
    } on Object catch (error) {
      return Left(databaseFailure(error));
    }
  }

  Future<void> _appendAuditLog({
    required String entityType,
    required String entityId,
    required String action,
    String? payload,
  }) async {
    await _auditLogLocalDataSource.appendLog(
      AuditLogModel(
        id: UuidUtil.generate(),
        entityType: entityType,
        entityId: entityId,
        action: action,
        payload: payload,
        timestamp: DateTime.now().toUtc(),
        deviceId: repositoryDeviceId,
      ),
    );
  }
}
