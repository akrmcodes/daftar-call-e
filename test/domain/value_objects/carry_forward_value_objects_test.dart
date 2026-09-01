import 'package:daftar/domain/entities/ledger.dart';
import 'package:daftar/domain/enums/ledger_type.dart';
import 'package:daftar/domain/value_objects/carry_forward_preview.dart';
import 'package:daftar/domain/value_objects/carry_forward_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 6);

  Ledger ledger(String id) {
    return Ledger(
      id: id,
      name: 'Ledger $id',
      type: LedgerType.custom,
      icon: 'folder',
      color: '#000000',
      sortOrder: 0,
      createdAt: now,
      updatedAt: now,
    );
  }

  group('CarryForwardPreview', () {
    test('supports value equality', () {
      const left = CarryForwardPreview(
        contactCount: 2,
        transactionCount: 5,
        totalsByCurrency: {'YER': 1000},
        sourceLedgerName: 'Source',
        targetLedgerName: 'Target',
      );
      const right = CarryForwardPreview(
        contactCount: 2,
        transactionCount: 5,
        totalsByCurrency: {'YER': 1000},
        sourceLedgerName: 'Source',
        targetLedgerName: 'Target',
      );

      expect(left, right);
    });
  });

  group('CarryForwardResult', () {
    test('supports value equality', () {
      final archived = ledger('archived-1');
      final left = CarryForwardResult(
        archivedLedger: archived,
        contactsCreated: 2,
        transactionsCreated: 4,
        targetLedgerId: 'target-1',
      );
      final right = CarryForwardResult(
        archivedLedger: archived,
        contactsCreated: 2,
        transactionsCreated: 4,
        targetLedgerId: 'target-1',
      );

      expect(left, right);
    });
  });
}
