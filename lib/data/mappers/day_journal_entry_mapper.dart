import 'package:daftar/data/datasources/local/drift_database.dart' as db;
import 'package:daftar/data/models/day_journal_entry_model.dart';
import 'package:daftar/domain/entities/day_journal_entry.dart' as domain;

/// Seamless conversions for day-journal domain, data, and Drift types.
extension DayJournalEntryDomainMapper on domain.DayJournalEntry {
  /// Converts a domain entry to the data-layer model.
  DayJournalEntryModel toModel() => DayJournalEntryModel.fromDomain(this);

  /// Converts a domain entry directly to a Drift row.
  db.DayJournalEntry toDrift() => toModel().toDrift();

  /// Converts a domain entry to a Drift companion.
  db.DayJournalEntriesCompanion toCompanion() => toModel().toCompanion();
}

/// Seamless conversions for generated Drift day-journal rows.
extension DayJournalEntryDriftMapper on db.DayJournalEntry {
  /// Converts a Drift row to the data-layer model.
  DayJournalEntryModel toModel() => DayJournalEntryModel.fromDrift(this);

  /// Converts a Drift row back to the domain entity.
  domain.DayJournalEntry toDomain() => toModel().toDomain();
}

/// Seamless conversions for generated Drift day-journal companions.
extension DayJournalEntryCompanionMapper on db.DayJournalEntriesCompanion {
  /// Converts a Drift companion to the data-layer model.
  DayJournalEntryModel toModel() => DayJournalEntryModel.fromCompanion(this);

  /// Converts a Drift companion back to the domain entity.
  domain.DayJournalEntry toDomain() => toModel().toDomain();

  /// Converts a Drift companion to a Drift row.
  db.DayJournalEntry toDrift() => toModel().toDrift();
}
