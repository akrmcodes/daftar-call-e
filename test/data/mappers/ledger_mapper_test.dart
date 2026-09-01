import 'package:daftar/data/mappers/ledger_mapper.dart';
import 'package:daftar/domain/entities/ledger.dart';
import 'package:daftar/domain/enums/ledger_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Ledger mapping', () {
    test('round-trips isUserArchived and carryForwardTargetLedgerId', () {
      final ledger = Ledger(
        id: 'ledger-archive-001',
        name: 'دفتر مؤرشف',
        type: LedgerType.custom,
        icon: 'archive',
        color: '#1F2937',
        sortOrder: 3,
        createdAt: DateTime.utc(2026, 4, 1, 9),
        updatedAt: DateTime.utc(2026, 4, 2, 10),
        isArchived: true,
        isUserArchived: true,
        carryForwardTargetLedgerId: 'target-ledger-uuid',
        syncVersion: 11,
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
}
