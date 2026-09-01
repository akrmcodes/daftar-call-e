import 'package:daftar/core/constants/db_constants.dart';
import 'package:daftar/data/datasources/local/drift_database.dart' as db;
import 'package:daftar/data/mappers/settings_mapper.dart';
import 'package:daftar/data/models/settings_model.dart';
import 'package:drift/drift.dart';

/// Local data source for app settings.
class SettingsLocalDataSource {
  /// Creates a settings local data source.
  SettingsLocalDataSource(this.database);

  /// Drift database dependency.
  final db.AppDatabase database;

  /// Returns the singleton settings row.
  Future<SettingsModel> getSettings() async {
    final row = await database.select(database.appSettingsTable).getSingle();
    return row.toModel();
  }

  /// Watches the singleton settings row.
  Stream<SettingsModel> watchSettings() {
    return database
        .select(database.appSettingsTable)
        .watchSingle()
        .map(
          (row) => row.toModel(),
        );
  }

  /// Clears persisted Google account linkage.
  ///
  /// Drift omits nullable columns set to `null` on upsert unless wrapped in
  /// [Value]; this uses an explicit [UpdateStatement.write] so SQL NULL is
  /// stored and [watchSettings] emits signed-out state.
  Future<void> clearGoogleAccountFields() async {
    await (database.update(database.appSettingsTable)
          ..where((t) => t.id.equals(DbConstants.appSettingsId)))
        .write(
      const db.AppSettingsTableCompanion(
        googleAccountId: Value(null),
        googleAccountEmail: Value(null),
        driveAutoBackupEnabled: Value(false),
        driveAutoBackupInterval: Value('daily'),
        lastAutoBackupOutcome: Value(null),
        lastAutoBackupFailureCode: Value(null),
      ),
    );
  }

  /// Updates the singleton settings row.
  Future<SettingsModel> updateSettings(SettingsModel settings) async {
    await database.into(database.appSettingsTable).insertOnConflictUpdate(
          settings.toCompanion(),
        );
    return settings;
  }
}
