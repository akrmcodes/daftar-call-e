import 'package:daftar/data/datasources/local/drift_database.dart' as db;
import 'package:drift/drift.dart' as drift;

/// Local data source for the singleton merchant profile row.
///
/// The merchant profile is modeled as a single-row table. These queries are
/// intentionally conservative and always operate on at most one row.
class MerchantProfileLocalDs {
  /// Creates a merchant profile local data source.
  MerchantProfileLocalDs(this.database);

  /// Drift database dependency.
  final db.AppDatabase database;

  /// Streams the latest merchant profile row, or `null` when none exists.
  Stream<db.MerchantProfileData?> watchProfile() {
    final query = database.select(database.merchantProfiles)
      ..orderBy([
        (table) => drift.OrderingTerm.desc(table.updatedAt),
      ])
      ..limit(1);

    return query.watchSingleOrNull();
  }

  /// Returns the single merchant profile row, or `null` if none exists.
  Future<db.MerchantProfileData?> getProfile() async {
    final query = database.select(database.merchantProfiles)
      ..orderBy([
        (table) => drift.OrderingTerm.desc(table.updatedAt),
      ])
      ..limit(1);

    return query.getSingleOrNull();
  }

  /// Inserts or updates the merchant profile row by primary key.
  Future<void> upsertProfile(db.MerchantProfilesCompanion companion) async {
    await database
        .into(database.merchantProfiles)
        .insertOnConflictUpdate(companion);
  }

  /// Updates only the logo path on the current merchant profile row.
  ///
  /// If no profile exists yet, the operation is a no-op.
  Future<void> updateLogoPath(String? newPath) async {
    final currentProfile = await getProfile();
    if (currentProfile == null) {
      return;
    }

    await (database.update(
      database.merchantProfiles,
    )..where((table) => table.id.equals(currentProfile.id))).write(
      db.MerchantProfilesCompanion(
        logoPath: drift.Value(newPath),
      ),
    );
  }
}
