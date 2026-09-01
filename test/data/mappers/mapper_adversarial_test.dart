import 'package:daftar/data/datasources/local/drift_database.dart' as db;
import 'package:daftar/data/mappers/audit_log_mapper.dart';
import 'package:daftar/data/mappers/audit_payload_mapper.dart';
import 'package:daftar/data/mappers/balance_mapper.dart';
import 'package:daftar/data/mappers/contact_mapper.dart';
import 'package:daftar/data/mappers/transaction_mapper.dart';
import 'package:daftar/data/models/contact_model.dart';
import 'package:daftar/data/models/transaction_model.dart';
import 'package:daftar/domain/entities/audit_log.dart' as domain;
import 'package:daftar/domain/entities/contact.dart' as domain;
import 'package:daftar/domain/entities/contact_balance.dart' as domain;
import 'package:daftar/domain/entities/transaction.dart' as domain;
import 'package:daftar/domain/enums/transaction_type.dart' as domain;
import 'package:drift/drift.dart' as drift;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Mapper adversarial', () {
    group('Contact mapping corruption', () {
      test('fromCompanion throws when required id is absent', () {
        const companion = db.ContactsCompanion(
          ledgerId: drift.Value('ledger-1'),
          name: drift.Value('عميل'),
          avatarColor: drift.Value('#000000'),
        );

        expect(
          () => ContactModel.fromCompanion(companion),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('id'),
            ),
          ),
        );
      });

      test('round-trips Arabic diacritic name without normalization loss', () {
        final contact = domain.Contact(
          id: 'contact-ar',
          ledgerId: 'ledger-1',
          name: 'أَحْمَد بِن فَاطِمَة',
          phone: '+967771234567',
          notes: 'ملاحظة',
          creditLimit: -5000,
          creditCurrency: 'YER',
          avatarColor: '#FF5722',
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026, 6),
          isArchived: true,
          syncVersion: 99,
        );

        expect(contact.toCompanion().toDomain(), equals(contact));
        expect(contact.toDrift().toDomain(), equals(contact));
      });
    });

    group('Transaction mapping corruption', () {
      test('fromCompanion throws when amount field is absent', () {
        const companion = db.TransactionsCompanion(
          id: drift.Value('txn-1'),
          contactId: drift.Value('contact-1'),
          type: drift.Value(domain.TransactionType.debt),
          currency: drift.Value('YER'),
        );

        expect(
          () => TransactionModel.fromCompanion(companion),
          throwsA(isA<StateError>()),
        );
      });

      test('round-trips max safe integer amount without truncation', () {
        final transaction = domain.Transaction(
          id: 'txn-max',
          contactId: 'contact-1',
          type: domain.TransactionType.debt,
          amount: 9007199254740991,
          currency: 'YER',
          description: 'حد أقصى',
          itemName: 'بضاعة',
          transactionDate: DateTime.utc(2026, 6, 17),
          createdAt: DateTime.utc(2026, 6, 17),
          updatedAt: DateTime.utc(2026, 6, 17),
          isDeleted: true,
          isArchived: true,
        );

        expect(transaction.toCompanion().toDomain(), equals(transaction));
        expect(transaction.toDrift().toDomain().amount, 9007199254740991);
      });
    });

    group('Balance mapping', () {
      test('round-trips negative net balance through drift row', () {
        final balance = domain.ContactBalance(
          contactId: 'contact-1',
          currencyCode: 'YER',
          totalDebt: 50000,
          totalPayment: 10000,
          netBalance: -40000,
          lastUpdatedAt: DateTime.utc(2026, 6, 17, 12),
        );

        expect(balance.toDrift().toDomain(), equals(balance));
        expect(balance.toCompanion().toDomain(), equals(balance));
        expect(balance.toCompanion().toDrift().toDomain(), equals(balance));
      });
    });

    group('Audit log mapping', () {
      test('round-trips null payload through companion', () {
        final log = domain.AuditLog(
          id: 'audit-1',
          entityType: 'contact',
          entityId: 'contact-1',
          action: 'CREATE',
          timestamp: DateTime.utc(2026, 6, 17),
          deviceId: 'device-abc',
        );

        expect(log.toCompanion().toDomain(), equals(log));
        expect(log.toDrift().toDomain(), equals(log));
      });
    });

    group('Audit payload corruption', () {
      test('contactCreateAuditPayload omits carryForward when null', () {
        final model = ContactModel(
          id: 'c1',
          ledgerId: 'l1',
          name: 'عميل',
          phone: null,
          notes: null,
          creditLimit: null,
          creditCurrency: null,
          avatarColor: '#000',
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        );

        final payload = contactCreateAuditPayload(model);

        expect(payload.containsKey('carryForwardOperationId'), isFalse);
        expect(payload['phone'], isNull);
        expect(payload['creditLimit'], isNull);
      });

      test('transactionCreateAuditPayload preserves integer amount not double', () {
        final model = TransactionModel(
          id: 't1',
          contactId: 'c1',
          type: domain.TransactionType.payment,
          amount: 1500,
          currency: 'YER',
          description: null,
          itemName: null,
          transactionDate: DateTime.utc(2026, 6, 17),
          attachmentPath: null,
          createdAt: DateTime.utc(2026, 6, 17),
          updatedAt: DateTime.utc(2026, 6, 17),
        );

        final payload = transactionCreateAuditPayload(model);

        expect(payload['amount'], isA<int>());
        expect(payload['amount'], 1500);
      });
    });
  });
}
