/// Database-related constants for the Daftar Drift schema.
///
/// Centralizes database configuration values to avoid magic strings
/// and numbers scattered across the data layer.
abstract final class DbConstants {
  /// Database file name on disk.
  static const String databaseName = 'daftar.db';

  /// Current schema version. Increment for every migration step.
  static const int schemaVersion = 28;

  /// Default page size for paginated queries.
  static const int defaultPageSize = 20;

  // ── Built-in Currency Codes ──────────────────────────────────────────

  /// Yemeni Rial — primary target market currency.
  static const String currencyYer = 'YER';

  /// Saudi Riyal — widely used in Yemen for imports/remittances.
  static const String currencySar = 'SAR';

  /// US Dollar — common reference currency.
  static const String currencyUsd = 'USD';

  // ── Default Settings ─────────────────────────────────────────────────

  /// Default locale for first launch.
  static const String defaultLocale = 'ar';

  /// Default theme mode for first launch (OLED battery saving).
  static const String defaultThemeMode = 'system';

  /// Default currency code for first launch.
  static const String defaultCurrency = currencyYer;

  /// Singleton row ID for the AppSettings table.
  static const int appSettingsId = 1;
}
