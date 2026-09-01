import 'package:drift/drift.dart';

/// Drift table definition for the `currencies` SQLite table.
///
/// Stores both built-in (YER, SAR, USD) and custom currencies.
/// Maps 1:1 to the domain `Currency` entity.
///
/// This is a reference data table — no sync fields needed.
/// Built-in currencies are seeded on first launch and cannot be deleted.
class Currencies extends Table {
  /// UUID v4 primary key.
  TextColumn get id => text()();

  /// ISO 4217 currency code (e.g., 'YER'). Must be unique.
  TextColumn get code => text().unique()();

  /// Display symbol (e.g., '﷼', '⃁', '$').
  /// Saudi Riyal stores U+20C1; presentation renders the official SAMA SVG.
  TextColumn get symbol => text()();

  /// Arabic display name (e.g., 'ريال يمني').
  TextColumn get nameAr => text()();

  /// English display name (e.g., 'Yemeni Rial').
  TextColumn get nameEn => text()();

  /// Number of decimal places for display formatting.
  IntColumn get decimalPlaces => integer()();

  /// Whether this is a system-seeded currency (cannot be deleted).
  BoolColumn get isBuiltIn =>
      boolean().withDefault(const Constant(false))();

  /// Whether this currency is available for selection in the UI.
  BoolColumn get isActive =>
      boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
