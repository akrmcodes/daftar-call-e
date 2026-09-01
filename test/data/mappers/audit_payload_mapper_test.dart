import 'dart:convert';

import 'package:daftar/data/mappers/audit_payload_mapper.dart';
import 'package:daftar/data/models/contact_model.dart';
import 'package:daftar/data/models/ledger_model.dart';
import 'package:daftar/data/models/transaction_model.dart';
import 'package:daftar/domain/enums/ledger_type.dart';
import 'package:daftar/domain/enums/transaction_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('audit payload mapper', () {
    test('contactCreateAuditPayload includes all standard fields', () {
      final model = ContactModel(
        id: 'contact-1',
        ledgerId: 'ledger-1',
        name: 'عميل',
        phone: '+967700000000',
        notes: 'ملاحظة',
        creditLimit: 50000,
        creditCurrency: 'YER',
        avatarColor: '#FF9800',
        createdAt: DateTime.utc(2026, 4),
        updatedAt: DateTime.utc(2026, 4, 2),
      );

      final payload = contactCreateAuditPayload(
        model,
        carryForwardOperationId: 'op-1',
      );

      expect(payload['id'], 'contact-1');
      expect(payload['ledgerId'], 'ledger-1');
      expect(payload['name'], 'عميل');
      expect(payload['phone'], '+967700000000');
      expect(payload['email'], isNull);
      expect(payload['notes'], 'ملاحظة');
      expect(payload['creditLimit'], 50000);
      expect(payload['creditCurrency'], 'YER');
      expect(payload['avatarColor'], '#FF9800');
      expect(payload['carryForwardOperationId'], 'op-1');

      final roundTrip = jsonDecode(jsonEncode(payload)) as Map<String, dynamic>;
      expect(roundTrip, payload);
    });

    test('transactionCreateAuditPayload includes all standard fields', () {
      final ceremonyAt = DateTime.utc(2026, 4, 3, 12);
      final model = TransactionModel(
        id: 'txn-1',
        contactId: 'contact-1',
        type: TransactionType.debt,
        amount: 2000,
        currency: 'YER',
        description: 'ترحيل',
        itemName: 'رصيد افتتاحي',
        transactionDate: ceremonyAt,
        attachmentPath: null,
        createdAt: ceremonyAt,
        updatedAt: ceremonyAt,
      );

      final payload = transactionCreateAuditPayload(
        model,
        carryForwardOperationId: 'op-1',
      );

      expect(payload['id'], 'txn-1');
      expect(payload['contactId'], 'contact-1');
      expect(payload['type'], 'debt');
      expect(payload['amount'], 2000);
      expect(payload['currency'], 'YER');
      expect(payload['description'], 'ترحيل');
      expect(payload['itemName'], 'رصيد افتتاحي');
      expect(payload['attachmentPath'], isNull);
      expect(payload['transactionDate'], ceremonyAt.toIso8601String());
      expect(payload['carryForwardOperationId'], 'op-1');

      final roundTrip = jsonDecode(jsonEncode(payload)) as Map<String, dynamic>;
      expect(roundTrip, payload);
    });

    test('ledgerCarryForwardUpdateAuditPayload includes archive fields', () {
      final model = LedgerModel(
        id: 'source-ledger',
        name: 'المصدر',
        type: LedgerType.custom,
        icon: 'folder',
        color: '#424242',
        sortOrder: 0,
        createdAt: DateTime.utc(2026, 4),
        updatedAt: DateTime.utc(2026, 4, 3),
        isUserArchived: true,
        carryForwardTargetLedgerId: 'target-ledger',
        syncVersion: 2,
      );

      final payload = ledgerCarryForwardUpdateAuditPayload(model);

      expect(payload['isUserArchived'], isTrue);
      expect(payload['carryForwardTargetLedgerId'], 'target-ledger');

      final roundTrip = jsonDecode(jsonEncode(payload)) as Map<String, dynamic>;
      expect(roundTrip, payload);
    });

    test('ledgerCarryForwardCeremonyAuditPayload includes ceremony metadata', () {
      final payload = ledgerCarryForwardCeremonyAuditPayload(
        operationId: 'op-1',
        sourceLedgerId: 'source-ledger',
        targetLedgerId: 'target-ledger',
        targetLedgerName: 'الهدف',
        contactsCreated: 2,
        transactionsCreated: 3,
        totalsByCurrency: const {'YER': -1500, 'USD': 200},
      );

      expect(payload['operationId'], 'op-1');
      expect(payload['sourceLedgerId'], 'source-ledger');
      expect(payload['targetLedgerId'], 'target-ledger');
      expect(payload['targetLedgerName'], 'الهدف');
      expect(payload['contactsCreated'], 2);
      expect(payload['transactionsCreated'], 3);
      expect(payload['totalsByCurrency'], {'YER': -1500, 'USD': 200});

      final roundTrip = jsonDecode(jsonEncode(payload)) as Map<String, dynamic>;
      expect(roundTrip['operationId'], 'op-1');
      expect(roundTrip['totalsByCurrency'], {'YER': -1500, 'USD': 200});
    });

    group('Negative and edge cases', () {
      test('contactCreateAuditPayload excludes carryForward key when omitted', () {
        final model = ContactModel(
          id: 'contact-2',
          ledgerId: 'ledger-2',
          name: 'زبون',
          phone: null,
          notes: null,
          creditLimit: null,
          creditCurrency: null,
          avatarColor: '#000000',
          createdAt: DateTime.utc(2026, 5),
          updatedAt: DateTime.utc(2026, 5, 2),
        );

        final payload = contactCreateAuditPayload(model);

        expect(payload.containsKey('carryForwardOperationId'), isFalse);
      });

      test('ledgerCarryForwardCeremonyAuditPayload preserves negative totals', () {
        final payload = ledgerCarryForwardCeremonyAuditPayload(
          operationId: 'op-neg',
          sourceLedgerId: 'src',
          targetLedgerId: 'tgt',
          targetLedgerName: 'هدف',
          contactsCreated: 0,
          transactionsCreated: 0,
          totalsByCurrency: const {'YER': -999999},
        );

        expect(payload['totalsByCurrency'], {'YER': -999999});
        final encoded = jsonEncode(payload);
        final decoded = jsonDecode(encoded) as Map<String, dynamic>;
        expect(decoded['totalsByCurrency'], {'YER': -999999});
      });
    });
  });
}
