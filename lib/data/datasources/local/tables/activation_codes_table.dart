import 'package:drift/drift.dart';

/// Drift table definition for the `activation_codes` SQLite table.
///
/// Stores premium activation codes and their validation status.
/// Maps 1:1 to the domain `ActivationCode` entity.
///
/// No sync fields — activation state is local-only.
class ActivationCodes extends Table {
  /// UUID v4 primary key.
  TextColumn get id => text()();

  /// The activation code string (e.g., 'XXXX-XXXX-XXXX').
  TextColumn get code => text()();

  /// UTC timestamp when the code was activated.
  DateTimeColumn get activatedAt => dateTime()();

  /// UTC timestamp when the activation expires.
  /// Null for lifetime activations.
  DateTimeColumn get expiresAt => dateTime().nullable()();

  /// Premium tier name (e.g., 'pro', 'business').
  TextColumn get tier => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
