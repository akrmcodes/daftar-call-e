import 'package:daftar/application/ledger/select_contact_net_balance.dart';
import 'package:daftar/domain/entities/contact.dart';
import 'package:daftar/domain/entities/contact_balance.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 6);

  Contact contact({String? creditCurrency}) {
    return Contact(
      id: 'c-1',
      ledgerId: 'l-1',
      name: 'Ali',
      creditCurrency: creditCurrency,
      avatarColor: '#5C6BC0',
      createdAt: now,
      updatedAt: now,
    );
  }

  ContactBalance balance(String code, int net) {
    return ContactBalance(
      contactId: 'c-1',
      currencyCode: code,
      totalDebt: net,
      totalPayment: 0,
      netBalance: net,
      lastUpdatedAt: now,
    );
  }

  group('selectContactNetBalance', () {
    test('returns first balance when credit currency is unset', () {
      final balances = [balance('YER', 120), balance('USD', 40)];

      expect(selectContactNetBalance(contact(), balances), 120);
      expect(selectContactDisplayCurrency(contact(), balances), 'YER');
    });

    test('falls back to first balance when preferred currency missing', () {
      final balances = [balance('YER', 90)];

      expect(
        selectContactNetBalance(contact(creditCurrency: 'USD'), balances),
        90,
      );
      expect(
        selectContactDisplayCurrency(contact(creditCurrency: 'USD'), balances),
        'YER',
      );
    });

    test('uses contact credit currency when balance row exists', () {
      final balances = [balance('YER', 90), balance('USD', 15)];

      expect(
        selectContactNetBalance(contact(creditCurrency: 'usd'), balances),
        15,
      );
      expect(
        selectContactDisplayCurrency(contact(creditCurrency: 'usd'), balances),
        'USD',
      );
    });
  });
}
