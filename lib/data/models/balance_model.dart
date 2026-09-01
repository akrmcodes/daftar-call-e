import 'package:daftar/data/datasources/local/drift_database.dart' as db;
import 'package:daftar/domain/entities/contact_balance.dart' as domain;

/// Data-layer representation of a contact balance row.
class BalanceModel {
  /// Creates a balance model.
  const BalanceModel({
    required this.contactId,
    required this.currencyCode,
    required this.totalDebt,
    required this.totalPayment,
    required this.netBalance,
    required this.lastUpdatedAt,
  });

  /// Creates a model from the domain entity.
  factory BalanceModel.fromDomain(domain.ContactBalance balance) {
    return BalanceModel(
      contactId: balance.contactId,
      currencyCode: balance.currencyCode,
      totalDebt: balance.totalDebt,
      totalPayment: balance.totalPayment,
      netBalance: balance.netBalance,
      lastUpdatedAt: balance.lastUpdatedAt,
    );
  }

  /// Contact identifier.
  final String contactId;

  /// Currency code.
  final String currencyCode;

  /// Sum of debt transactions.
  final int totalDebt;

  /// Sum of payment transactions.
  final int totalPayment;

  /// Net balance.
  final int netBalance;

  /// Last recalculation timestamp.
  final DateTime lastUpdatedAt;

  /// Converts this model back to the domain entity.
  domain.ContactBalance toDomain() {
    return domain.ContactBalance(
      contactId: contactId,
      currencyCode: currencyCode,
      totalDebt: totalDebt,
      totalPayment: totalPayment,
      netBalance: netBalance,
      lastUpdatedAt: lastUpdatedAt,
    );
  }

  /// Converts this model to the generated Drift row.
  db.ContactBalance toDrift() {
    return db.ContactBalance(
      contactId: contactId,
      currencyCode: currencyCode,
      totalDebt: totalDebt,
      totalPayment: totalPayment,
      netBalance: netBalance,
      lastUpdatedAt: lastUpdatedAt,
    );
  }

  /// Converts this model to a Drift companion.
  db.ContactBalancesCompanion toCompanion() => toDrift().toCompanion(false);
}
