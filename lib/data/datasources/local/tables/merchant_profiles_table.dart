import 'package:drift/drift.dart';

/// Drift table definition for the `merchant_profiles` SQLite table.
///
/// Stores the merchant branding profile used by the local data layer and
/// future PDF header rendering.
@DataClassName('MerchantProfileData')
class MerchantProfiles extends Table {
  /// UUID v4 primary key.
  TextColumn get id => text()();

  /// Merchant store display name.
  TextColumn get storeName => text()();

  /// Optional contact phone number for the store.
  TextColumn get storePhone => text().nullable()();

  /// Optional local file path to the stored logo asset.
  TextColumn get logoPath => text().nullable()();

  /// UTC timestamp of creation.
  DateTimeColumn get createdAt => dateTime()();

  /// UTC timestamp of last modification.
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
