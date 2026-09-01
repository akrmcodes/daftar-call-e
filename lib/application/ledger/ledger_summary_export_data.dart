import 'package:daftar/domain/entities/contact_balance.dart';

/// Immutable payload for ledger-level PDF summary export.
class LedgerSummaryExportData {
  /// Creates export data for a single ledger.
  const LedgerSummaryExportData({
    required this.ledgerName,
    required this.contacts,
    required this.ledgerTotals,
  });

  /// Display name of the ledger.
  final String ledgerName;

  /// Contacts with their display net balance (one row per contact).
  final List<LedgerSummaryContactRow> contacts;

  /// Ledger-wide totals aggregated per currency.
  final List<ContactBalance> ledgerTotals;
}

/// One contact row in the ledger summary table.
class LedgerSummaryContactRow {
  /// Creates a summary row for PDF rendering.
  const LedgerSummaryContactRow({
    required this.name,
    required this.netBalance,
    required this.currencyCode,
    this.phone,
  });

  /// Contact display name.
  final String name;

  /// Optional phone number.
  final String? phone;

  /// Net balance in smallest currency unit for [currencyCode].
  final int netBalance;

  /// ISO-4217 currency code for [netBalance].
  final String currencyCode;
}
