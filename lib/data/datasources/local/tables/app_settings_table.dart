import 'package:daftar/core/constants/db_constants.dart';
import 'package:drift/drift.dart';

/// Drift table definition for the `app_settings_table` SQLite table.
///
/// Single-row table storing application-wide user preferences.
/// Maps 1:1 to the domain `AppSettings` entity.
///
/// The [id] column always has the value [DbConstants.appSettingsId] (1)
/// to enforce the single-row constraint. A default row is inserted
/// during database creation (schema migration v1).
///
/// No sync fields — settings are local-only.
class AppSettingsTable extends Table {
  /// Singleton row ID (always [DbConstants.appSettingsId]).
  IntColumn get id =>
      integer().withDefault(const Constant(DbConstants.appSettingsId))();

  /// Active locale code ('ar' or 'en'). Arabic is default.
  TextColumn get locale =>
      text().withDefault(const Constant(DbConstants.defaultLocale))();

  /// Active theme mode ('dark', 'light', 'system'). Dark is default.
  TextColumn get themeMode =>
      text().withDefault(const Constant(DbConstants.defaultThemeMode))();

  /// Reference key for PIN hash in flutter_secure_storage.
  /// Null if PIN lock is not set.
  TextColumn get pinHash => text().nullable()();

  /// Whether app lock is enabled (requires a configured PIN).
  BoolColumn get isAppLockEnabled =>
      boolean().withDefault(const Constant(false))();

  /// Whether biometric unlock is enabled.
  BoolColumn get biometricEnabled =>
      boolean().withDefault(const Constant(false))();

  /// Seconds in background before the app re-locks on resume.
  IntColumn get lockTimeoutSeconds =>
      integer().withDefault(const Constant(60))();

  /// ISO 4217 code for the default currency.
  TextColumn get defaultCurrency =>
      text().withDefault(const Constant(DbConstants.defaultCurrency))();

  /// UTC timestamp of the last successful backup. Null if never backed up.
  DateTimeColumn get lastBackupAt => dateTime().nullable()();

  /// Whether Firebase Analytics collection is active.
  BoolColumn get analyticsEnabled =>
      boolean().withDefault(const Constant(true))();

  /// Google user id when signed in for cloud backup; null otherwise.
  TextColumn get googleAccountId => text().nullable()();

  /// Google account email when signed in; null otherwise.
  TextColumn get googleAccountEmail => text().nullable()();

  /// Whether periodic Google Drive auto-backup is enabled.
  BoolColumn get driveAutoBackupEnabled =>
      boolean().withDefault(const Constant(false))();

  /// Auto-backup cadence storage key (`daily` or `weekly`).
  TextColumn get driveAutoBackupInterval =>
      text().withDefault(const Constant('daily'))();

  /// When false, new records use [defaultCurrency] without per-form selection.
  BoolColumn get isMultiCurrencyEnabled =>
      boolean().withDefault(const Constant(false))();

  /// When true, contact and transaction list tiles support swipe-to-delete.
  BoolColumn get isSwipeToDeleteEnabled =>
      boolean().withDefault(const Constant(false))();

  /// Whether the first-run onboarding walkthrough has been completed.
  BoolColumn get hasSeenOnboarding =>
      boolean().withDefault(const Constant(false))();

  /// Whether the Closing Agent FAB first-run tip has been shown.
  BoolColumn get hasSeenAgentFabTip =>
      boolean().withDefault(const Constant(false))();

  /// When true, skip on-device TTS for confirm read-back and closing report.
  BoolColumn get ttsMuted => boolean().withDefault(const Constant(false))();

  /// When true, show the contest Architecture HUD overlay (debug / demo).
  BoolColumn get demoArchitectureHud =>
      boolean().withDefault(const Constant(false))();

  /// Outcome of the last automatic Drive backup (`success`, `failed`, `skipped`).
  TextColumn get lastAutoBackupOutcome => text().nullable()();

  /// Machine-readable failure code from the last automatic Drive backup.
  TextColumn get lastAutoBackupFailureCode => text().nullable()();

  /// Server-supplied cursor for the next `pull-sync-ops` request.
  ///
  /// Device-local sync bookkeeping, not a user preference. It cannot be
  /// derived from the applied op log: the server withholds ops this
  /// workspace must not replay (archived-ledger children), so its cursor
  /// legitimately runs ahead of `MAX(sync_operations.op_seq)`.
  IntColumn get syncPullWatermarkOpSeq =>
      integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
