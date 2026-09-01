import 'package:daftar/data/datasources/local/drift_database.dart' as db;
import 'package:daftar/data/mappers/contact_mapper.dart';
import 'package:daftar/data/mappers/currency_mapper.dart';
import 'package:daftar/data/mappers/ledger_mapper.dart';
import 'package:daftar/data/mappers/transaction_mapper.dart';
import 'package:daftar/domain/entities/contact.dart' as domain;
import 'package:daftar/domain/entities/currency.dart' as domain;
import 'package:daftar/domain/entities/ledger.dart' as domain;
import 'package:daftar/domain/entities/transaction.dart' as domain;
import 'package:daftar/domain/enums/ledger_type.dart' as domain;
import 'package:daftar/domain/enums/transaction_type.dart' as domain;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Ledger mapping', () {
    test('round-trips through model, row, and companion', () {
      final ledger = domain.Ledger(
        id: 'ledger-001',
        name: 'دفتر البقالة',
        type: domain.LedgerType.custom,
        icon: 'storefront',
        color: '#1F2937',
        sortOrder: 42,
        createdAt: DateTime.utc(2026, 3, 28, 9),
        updatedAt: DateTime.utc(2026, 3, 29, 10),
        isDeleted: true,
        syncVersion: 7,
      );

      final model = ledger.toModel();

      expect(model.toDomain(), equals(ledger));
      expect(model.toDrift().toDomain(), equals(ledger));
      expect(ledger.toDrift().toDomain(), equals(ledger));
      expect(ledger.toCompanion().toDomain(), equals(ledger));
      expect(ledger.toCompanion().toModel().toDomain(), equals(ledger));
      expect(ledger.toCompanion().toDrift().toDomain(), equals(ledger));
    });
  });

  group('Contact mapping', () {
    test('round-trips through model, row, and companion', () {
      final contact = domain.Contact(
        id: 'contact-001',
        ledgerId: 'ledger-001',
        name: 'محمد أحمد',
        notes: 'زبون منتظم',
        creditLimit: 150000,
        creditCurrency: 'YER',
        avatarColor: '#0EA5E9',
        createdAt: DateTime.utc(2026, 3, 28, 11),
        updatedAt: DateTime.utc(2026, 3, 30, 12),
        syncVersion: 3,
      );

      final model = contact.toModel();

      expect(model.toDomain(), equals(contact));
      expect(model.toDrift().toDomain(), equals(contact));
      expect(contact.toDrift().toDomain(), equals(contact));
      expect(contact.toCompanion().toDomain(), equals(contact));
      expect(contact.toCompanion().toModel().toDomain(), equals(contact));
      expect(contact.toCompanion().toDrift().toDomain(), equals(contact));
    });
  });

  group('Transaction mapping', () {
    test('round-trips through model, row, and companion', () {
      final transaction = domain.Transaction(
        id: 'transaction-001',
        contactId: 'contact-001',
        type: domain.TransactionType.payment,
        amount: 98765,
        currency: 'SAR',
        itemName: 'سكر',
        transactionDate: DateTime.utc(2026, 4, 1, 7, 30),
        attachmentPath: '/tmp/receipt.pdf',
        createdAt: DateTime.utc(2026, 4, 1, 7, 45),
        updatedAt: DateTime.utc(2026, 4, 2, 8),
        isDeleted: true,
        syncVersion: 11,
      );

      final model = transaction.toModel();

      expect(model.toDomain(), equals(transaction));
      expect(model.toDrift().toDomain(), equals(transaction));
      expect(transaction.toDrift().toDomain(), equals(transaction));
      expect(transaction.toCompanion().toDomain(), equals(transaction));
      expect(
        transaction.toCompanion().toModel().toDomain(),
        equals(transaction),
      );
      expect(
        transaction.toCompanion().toDrift().toDomain(),
        equals(transaction),
      );
    });
  });

  group('Currency mapping', () {
    test('round-trips through row and companion mappings', () {
      const currency = domain.Currency(
        id: 'currency-001',
        code: 'YER',
        symbol: '﷼',
        nameAr: 'ريال يمني',
        nameEn: 'Yemeni Rial',
        decimalPlaces: 2,
        isBuiltIn: true,
        isActive: false,
      );

      expect(currency.toDrift().toDomain(), equals(currency));
      expect(currency.toCompanion().toDomain(), equals(currency));
      expect(currency.toCompanion().toDrift().toDomain(), equals(currency));
    });
  });

  test('generated Drift row mapping stays type-safe', () {
    const row = db.Currency(
      id: 'currency-002',
      code: 'USD',
      symbol: r'$',
      nameAr: 'دولار أمريكي',
      nameEn: 'US Dollar',
      decimalPlaces: 2,
      isBuiltIn: true,
      isActive: true,
    );

    expect(row.toDomain().code, equals('USD'));
    expect(row.toCompanion(false).toDomain().code, equals('USD'));
  });
}
