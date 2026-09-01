import 'package:daftar/domain/entities/contact.dart';
import 'package:daftar/domain/entities/contact_balance.dart';

/// Picks the net balance shown in lists and ledger summaries for [contact].
///
/// Prefers [Contact.creditCurrency] when set; otherwise uses the first balance
/// row returned by the repository (stable currency ordering).
int selectContactNetBalance(Contact contact, List<ContactBalance> balances) {
  if (balances.isEmpty) {
    return 0;
  }

  final preferredCurrency = contact.creditCurrency?.trim().toUpperCase();
  if (preferredCurrency != null && preferredCurrency.isNotEmpty) {
    for (final balance in balances) {
      if (balance.currencyCode.trim().toUpperCase() == preferredCurrency) {
        return balance.netBalance;
      }
    }
  }

  return balances.first.netBalance;
}

/// Currency code paired with [selectContactNetBalance].
String selectContactDisplayCurrency(
  Contact contact,
  List<ContactBalance> balances,
) {
  if (balances.isEmpty) {
    return contact.creditCurrency?.trim().toUpperCase() ?? '';
  }

  final preferredCurrency = contact.creditCurrency?.trim().toUpperCase();
  if (preferredCurrency != null && preferredCurrency.isNotEmpty) {
    for (final balance in balances) {
      if (balance.currencyCode.trim().toUpperCase() == preferredCurrency) {
        return balance.currencyCode.trim().toUpperCase();
      }
    }
  }

  return balances.first.currencyCode.trim().toUpperCase();
}
