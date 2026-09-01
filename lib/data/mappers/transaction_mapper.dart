import 'package:daftar/data/datasources/local/drift_database.dart' as db;
import 'package:daftar/data/models/transaction_model.dart';
import 'package:daftar/domain/entities/transaction.dart' as domain;

/// Seamless conversions for transaction domain, data, and Drift types.
extension TransactionDomainMapper on domain.Transaction {
  /// Converts a domain transaction to the data-layer model.
  TransactionModel toModel() => TransactionModel.fromDomain(this);

  /// Converts a domain transaction directly to a Drift row.
  db.Transaction toDrift() => toModel().toDrift();

  /// Converts a domain transaction to a Drift companion.
  db.TransactionsCompanion toCompanion() => toModel().toCompanion();
}

/// Seamless conversions for generated Drift transaction rows.
extension TransactionDriftMapper on db.Transaction {
  /// Converts a Drift transaction row to the data-layer model.
  TransactionModel toModel() => TransactionModel.fromDrift(this);

  /// Converts a Drift transaction row back to the domain entity.
  domain.Transaction toDomain() => toModel().toDomain();
}

/// Seamless conversions for generated Drift transaction companions.
extension TransactionCompanionMapper on db.TransactionsCompanion {
  /// Converts a Drift transaction companion to the data-layer model.
  TransactionModel toModel() => TransactionModel.fromCompanion(this);

  /// Converts a Drift transaction companion back to the domain entity.
  domain.Transaction toDomain() => toModel().toDomain();

  /// Converts a Drift transaction companion to a Drift row.
  db.Transaction toDrift() => toModel().toDrift();
}
