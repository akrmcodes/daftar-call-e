import 'package:daftar/data/datasources/local/drift_database.dart' as db;
import 'package:daftar/data/models/balance_model.dart';
import 'package:daftar/domain/entities/contact_balance.dart' as domain;

/// Seamless conversions for contact balance domain, data, and Drift types.
extension BalanceDomainMapper on domain.ContactBalance {
  /// Converts a domain balance to the data-layer model.
  BalanceModel toModel() => BalanceModel.fromDomain(this);

  /// Converts a domain balance directly to a Drift row.
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

  /// Converts a domain balance to a Drift companion.
  db.ContactBalancesCompanion toCompanion() => toDrift().toCompanion(false);
}

/// Seamless conversions for generated Drift balance rows.
extension BalanceDriftMapper on db.ContactBalance {
  /// Converts a Drift balance row to the data-layer model.
  BalanceModel toModel() {
    return BalanceModel(
      contactId: contactId,
      currencyCode: currencyCode,
      totalDebt: totalDebt,
      totalPayment: totalPayment,
      netBalance: netBalance,
      lastUpdatedAt: lastUpdatedAt,
    );
  }

  /// Converts a Drift balance row back to the domain entity.
  domain.ContactBalance toDomain() => toModel().toDomain();
}

/// Seamless conversions for generated Drift balance companions.
extension BalanceCompanionMapper on db.ContactBalancesCompanion {
  /// Converts a Drift balance companion to the data-layer model.
  BalanceModel toModel() {
    return BalanceModel(
      contactId: contactId.value,
      currencyCode: currencyCode.value,
      totalDebt: totalDebt.value,
      totalPayment: totalPayment.value,
      netBalance: netBalance.value,
      lastUpdatedAt: lastUpdatedAt.value,
    );
  }

  /// Converts a Drift balance companion back to the domain entity.
  domain.ContactBalance toDomain() => toModel().toDomain();

  /// Converts a Drift balance companion to a Drift row.
  db.ContactBalance toDrift() => toModel().toDrift();
}
