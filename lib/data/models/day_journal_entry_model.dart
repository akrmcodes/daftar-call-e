import 'package:daftar/data/datasources/local/drift_database.dart' as db;
import 'package:daftar/domain/entities/day_journal_entry.dart' as domain;
import 'package:daftar/domain/enums/day_journal_kind.dart';
import 'package:drift/drift.dart' as drift;

/// Data-layer representation of a day-journal entry.
class DayJournalEntryModel {
  /// Creates a day-journal data model.
  const DayJournalEntryModel({
    required this.id,
    required this.localDay,
    required this.kind,
    required this.payloadJson,
    required this.createdAt,
    this.ledgerId,
    this.contactId,
    this.amount,
    this.currencyCode,
    this.proposalId,
    this.sessionId,
  });

  /// Builds a data model from a domain entity.
  factory DayJournalEntryModel.fromDomain(domain.DayJournalEntry entry) {
    return DayJournalEntryModel(
      id: entry.id,
      localDay: entry.localDay,
      kind: entry.kind,
      payloadJson: entry.payloadJson,
      createdAt: entry.createdAt,
      ledgerId: entry.ledgerId,
      contactId: entry.contactId,
      amount: entry.amount,
      currencyCode: entry.currencyCode,
      proposalId: entry.proposalId,
      sessionId: entry.sessionId,
    );
  }

  /// Builds a data model from a Drift row.
  factory DayJournalEntryModel.fromDrift(db.DayJournalEntry entry) {
    return DayJournalEntryModel(
      id: entry.id,
      localDay: entry.localDay,
      kind: entry.kind,
      payloadJson: entry.payloadJson,
      createdAt: entry.createdAt,
      ledgerId: entry.ledgerId,
      contactId: entry.contactId,
      amount: entry.amount,
      currencyCode: entry.currencyCode,
      proposalId: entry.proposalId,
      sessionId: entry.sessionId,
    );
  }

  /// Rebuilds a model from a populated Drift companion.
  factory DayJournalEntryModel.fromCompanion(
    db.DayJournalEntriesCompanion companion,
  ) {
    return DayJournalEntryModel(
      id: _requiredValue(companion.id, 'id'),
      localDay: _requiredValue(companion.localDay, 'localDay'),
      kind: _requiredValue(companion.kind, 'kind'),
      payloadJson: _requiredValue(companion.payloadJson, 'payloadJson'),
      createdAt: _requiredValue(companion.createdAt, 'createdAt'),
      ledgerId: _optionalNullableValue(companion.ledgerId),
      contactId: _optionalNullableValue(companion.contactId),
      amount: _optionalNullableValue(companion.amount),
      currencyCode: _optionalNullableValue(companion.currencyCode),
      proposalId: _optionalNullableValue(companion.proposalId),
      sessionId: _optionalNullableValue(companion.sessionId),
    );
  }

  /// Unique identifier.
  final String id;

  /// Calendar day `YYYY-MM-DD`.
  final String localDay;

  /// Event kind.
  final DayJournalKind kind;

  /// JSON payload.
  final String payloadJson;

  /// UTC append timestamp.
  final DateTime createdAt;

  /// Optional ledger UUID.
  final String? ledgerId;

  /// Optional contact UUID.
  final String? contactId;

  /// Optional integer minor-unit amount.
  final int? amount;

  /// Optional ISO currency code.
  final String? currencyCode;

  /// Optional proposal id.
  final String? proposalId;

  /// Optional session id.
  final String? sessionId;

  /// Converts this model back to the domain entity.
  domain.DayJournalEntry toDomain() {
    return domain.DayJournalEntry(
      id: id,
      localDay: localDay,
      kind: kind,
      payloadJson: payloadJson,
      createdAt: createdAt,
      ledgerId: ledgerId,
      contactId: contactId,
      amount: amount,
      currencyCode: currencyCode,
      proposalId: proposalId,
      sessionId: sessionId,
    );
  }

  /// Converts this model to the generated Drift row type.
  db.DayJournalEntry toDrift() {
    return db.DayJournalEntry(
      id: id,
      localDay: localDay,
      kind: kind,
      payloadJson: payloadJson,
      createdAt: createdAt,
      ledgerId: ledgerId,
      contactId: contactId,
      amount: amount,
      currencyCode: currencyCode,
      proposalId: proposalId,
      sessionId: sessionId,
    );
  }

  /// Converts this model to a Drift companion suitable for persistence.
  db.DayJournalEntriesCompanion toCompanion() {
    return toDrift().toCompanion(false);
  }
}

T _requiredValue<T>(drift.Value<T> value, String fieldName) {
  if (!value.present) {
    throw StateError(
      'Missing required field "$fieldName" in Drift companion.',
    );
  }
  return value.value;
}

T? _optionalNullableValue<T>(drift.Value<T?> value) {
  return value.present ? value.value : null;
}
