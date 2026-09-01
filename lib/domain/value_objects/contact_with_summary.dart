import 'package:equatable/equatable.dart';

class ContactWithSummary extends Equatable {
  const ContactWithSummary({
    required this.contactId,
    required this.ledgerId,
    required this.name,
    required this.phone,
    required this.avatarColor,
    required this.creditLimit,
    required this.creditCurrency,
    required this.transactionCount,
    required this.balances,
  });

  final String contactId;
  final String ledgerId;
  final String name;
  final String? phone;
  final String avatarColor;
  final int? creditLimit;
  final String? creditCurrency;
  final int transactionCount;
  final List<ContactBalanceSummary> balances;

  @override
  List<Object?> get props => [
    contactId,
    ledgerId,
    name,
    phone,
    avatarColor,
    creditLimit,
    creditCurrency,
    transactionCount,
    balances,
  ];
}

class ContactBalanceSummary extends Equatable {
  const ContactBalanceSummary({
    required this.currencyCode,
    required this.totalDebt,
    required this.totalPayment,
    required this.netBalance,
  });

  final String currencyCode;
  final int totalDebt;
  final int totalPayment;
  final int netBalance;

  @override
  List<Object?> get props => [
    currencyCode,
    totalDebt,
    totalPayment,
    netBalance,
  ];
}
