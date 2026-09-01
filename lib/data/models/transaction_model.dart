import 'package:daftar/data/datasources/local/drift_database.dart' as db;
import 'package:daftar/domain/entities/transaction.dart' as domain;
import 'package:daftar/domain/enums/transaction_type.dart';
import 'package:drift/drift.dart' as drift;

/// Data-layer representation of a transaction.
///
/// The model is the authoritative bridge between the domain entity and the
/// generated Drift row/companion types.
class TransactionModel {
  /// Creates a transaction data model.
  const TransactionModel({
    required this.id,
    required this.contactId,
    required this.type,
    required this.amount,
    required this.currency,
    required this.description,
    required this.itemName,
    required this.transactionDate,
    required this.attachmentPath,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.isArchived = false,
    this.syncVersion = 0,
  });

  /// Builds a data model from a domain entity.
  factory TransactionModel.fromDomain(domain.Transaction transaction) {
    return TransactionModel(
      id: transaction.id,
      contactId: transaction.contactId,
      type: transaction.type,
      amount: transaction.amount,
      currency: transaction.currency,
      description: transaction.description,
      itemName: transaction.itemName,
      transactionDate: transaction.transactionDate,
      attachmentPath: transaction.attachmentPath,
      createdAt: transaction.createdAt,
      updatedAt: transaction.updatedAt,
      isDeleted: transaction.isDeleted,
      isArchived: transaction.isArchived,
      syncVersion: transaction.syncVersion,
    );
  }

  /// Builds a data model from a Drift row.
  factory TransactionModel.fromDrift(db.Transaction transaction) {
    return TransactionModel(
      id: transaction.id,
      contactId: transaction.contactId,
      type: transaction.type,
      amount: transaction.amount,
      currency: transaction.currency,
      description: transaction.description,
      itemName: transaction.itemName,
      transactionDate: transaction.transactionDate,
      attachmentPath: transaction.attachmentPath,
      createdAt: transaction.createdAt,
      updatedAt: transaction.updatedAt,
      isDeleted: transaction.isDeleted,
      isArchived: transaction.isArchived,
      syncVersion: transaction.syncVersion,
    );
  }

  /// Rebuilds a model from a populated Drift companion.
  factory TransactionModel.fromCompanion(
    db.TransactionsCompanion companion,
  ) {
    return TransactionModel(
      id: _requiredValue(companion.id, 'id'),
      contactId: _requiredValue(companion.contactId, 'contactId'),
      type: _requiredValue(companion.type, 'type'),
      amount: _requiredValue(companion.amount, 'amount'),
      currency: _requiredValue(companion.currency, 'currency'),
      description: _optionalValue(companion.description, null),
      itemName: _optionalValue(companion.itemName, null),
      transactionDate: _requiredValue(
        companion.transactionDate,
        'transactionDate',
      ),
      attachmentPath: _optionalValue(companion.attachmentPath, null),
      createdAt: _requiredValue(companion.createdAt, 'createdAt'),
      updatedAt: _requiredValue(companion.updatedAt, 'updatedAt'),
      isDeleted: _optionalValue(companion.isDeleted, false),
      isArchived: _optionalValue(companion.isArchived, false),
      syncVersion: _optionalValue(companion.syncVersion, 0),
    );
  }

  /// Unique identifier.
  final String id;

  /// Parent contact identifier.
  final String contactId;

  /// Transaction direction.
  final TransactionType type;

  /// Amount in the smallest currency unit.
  final int amount;

  /// ISO 4217 currency code.
  final String currency;

  /// Optional transaction description.
  final String? description;

  /// Optional item name for autocomplete.
  final String? itemName;

  /// Date the transaction occurred.
  final DateTime transactionDate;

  /// Optional attachment path.
  final String? attachmentPath;

  /// UTC creation timestamp.
  final DateTime createdAt;

  /// UTC last-update timestamp.
  final DateTime updatedAt;

  /// Soft-delete flag.
  final bool isDeleted;

  /// Archive-first import flag.
  final bool isArchived;

  /// Sync conflict resolution version.
  final int syncVersion;

  /// Converts this model back to the domain entity.
  domain.Transaction toDomain() {
    return domain.Transaction(
      id: id,
      contactId: contactId,
      type: type,
      amount: amount,
      currency: currency,
      description: description,
      itemName: itemName,
      transactionDate: transactionDate,
      attachmentPath: attachmentPath,
      createdAt: createdAt,
      updatedAt: updatedAt,
      isDeleted: isDeleted,
      isArchived: isArchived,
      syncVersion: syncVersion,
    );
  }

  /// Converts this model to the generated Drift row type.
  db.Transaction toDrift() {
    return db.Transaction(
      id: id,
      contactId: contactId,
      type: type,
      amount: amount,
      currency: currency,
      description: description,
      itemName: itemName,
      transactionDate: transactionDate,
      attachmentPath: attachmentPath,
      createdAt: createdAt,
      updatedAt: updatedAt,
      isDeleted: isDeleted,
      isArchived: isArchived,
      syncVersion: syncVersion,
    );
  }

  /// Converts this model to a Drift companion suitable for persistence.
  db.TransactionsCompanion toCompanion() {
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

T _optionalValue<T>(drift.Value<T> value, T fallback) {
  return value.present ? value.value : fallback;
}
