import 'package:drift/drift.dart';

class ContactSummaryRow {
  const ContactSummaryRow({
    required this.contactId,
    required this.name,
    required this.phone,
    required this.avatarColor,
    required this.creditLimit,
    required this.creditCurrency,
    required this.currencyCode,
    required this.totalDebt,
    required this.totalPayment,
    required this.netBalance,
    required this.transactionCount,
  });

  factory ContactSummaryRow.fromQueryRow(QueryRow row) {
    return ContactSummaryRow(
      contactId: row.read<String>('contact_id'),
      name: row.read<String>('name'),
      phone: row.readNullable<String>('phone'),
      avatarColor: row.read<String>('avatar_color'),
      creditLimit: row.readNullable<int>('credit_limit'),
      creditCurrency: row.readNullable<String>('credit_currency'),
      currencyCode: row.readNullable<String>('currency_code'),
      totalDebt: row.readNullable<int>('total_debt'),
      totalPayment: row.readNullable<int>('total_payment'),
      netBalance: row.readNullable<int>('net_balance'),
      transactionCount: row.read<int>('txn_count'),
    );
  }

  final String contactId;
  final String name;
  final String? phone;
  final String avatarColor;
  final int? creditLimit;
  final String? creditCurrency;
  final String? currencyCode;
  final int? totalDebt;
  final int? totalPayment;
  final int? netBalance;
  final int transactionCount;
}
