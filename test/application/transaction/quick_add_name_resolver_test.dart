import 'package:daftar/application/transaction/quick_add_name_resolver.dart';
import 'package:daftar/application/transaction/quick_add_state.dart';
import 'package:daftar/domain/entities/contact.dart';
import 'package:daftar/domain/entities/ledger.dart';
import 'package:daftar/domain/enums/ledger_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 6);

  Ledger ledger(String id, {int sortOrder = 0}) {
    return Ledger(
      id: id,
      name: id,
      type: LedgerType.custom,
      icon: 'folder',
      color: '#000000',
      sortOrder: sortOrder,
      createdAt: now,
      updatedAt: now,
    );
  }

  Contact contact(String id, String ledgerId) {
    return Contact(
      id: id,
      ledgerId: ledgerId,
      name: 'contact-$id',
      avatarColor: '#5C6BC0',
      createdAt: now,
      updatedAt: now,
    );
  }

  group('QuickAddNameResolver', () {
    test('resolve returns newAccount with primary ledger for empty matches', () {
      final ledgers = [ledger('l-1'), ledger('l-2', sortOrder: 1)];

      final resolution = QuickAddNameResolver.resolve(
        matches: const [],
        availableLedgers: ledgers,
      );

      expect(resolution.mode, QuickAddAccountResolution.newAccount);
      expect(resolution.selectedLedgerId, 'l-1');
    });

    test('resolve auto-selects single ledger for all matches', () {
      final resolution = QuickAddNameResolver.resolve(
        matches: [
          contact('c-1', 'l-9'),
          contact('c-2', 'l-9'),
        ],
        availableLedgers: [ledger('l-9')],
      );

      expect(resolution.mode, QuickAddAccountResolution.singleLedgerAuto);
      expect(resolution.selectedLedgerId, 'l-9');
    });

    test('resolve clears ledger when matches span multiple ledgers', () {
      final resolution = QuickAddNameResolver.resolve(
        matches: [
          contact('c-1', 'l-1'),
          contact('c-2', 'l-2'),
        ],
        availableLedgers: [ledger('l-1'), ledger('l-2', sortOrder: 1)],
      );

      expect(resolution.mode, QuickAddAccountResolution.multiLedgerPick);
      expect(resolution.selectedLedgerId, isNull);
    });

    test('reconcileSelectedLedger keeps valid multi-ledger pick', () {
      final ledgers = [ledger('l-1'), ledger('l-2', sortOrder: 1)];
      final matches = [contact('c-1', 'l-2')];

      final reconciled = QuickAddNameResolver.reconcileSelectedLedger(
        current: 'l-2',
        resolution: QuickAddAccountResolution.multiLedgerPick,
        availableLedgers: ledgers,
        matchedContacts: matches,
      );

      expect(reconciled, 'l-2');
    });

    test('reconcileSelectedLedger clears invalid multi-ledger pick', () {
      final ledgers = [ledger('l-1'), ledger('l-2', sortOrder: 1)];
      final matches = [contact('c-1', 'l-1')];

      final reconciled = QuickAddNameResolver.reconcileSelectedLedger(
        current: 'l-2',
        resolution: QuickAddAccountResolution.multiLedgerPick,
        availableLedgers: ledgers,
        matchedContacts: matches,
      );

      expect(reconciled, isNull);
    });

    test('reconcileSelectedLedger falls back to primary ledger for idle mode', () {
      final ledgers = [ledger('l-1'), ledger('l-2', sortOrder: 1)];

      final reconciled = QuickAddNameResolver.reconcileSelectedLedger(
        current: 'missing',
        resolution: QuickAddAccountResolution.idle,
        availableLedgers: ledgers,
        matchedContacts: const [],
      );

      expect(reconciled, 'l-1');
    });

    test('reconcileSelectedLedger keeps valid pick in single ledger auto mode', () {
      final ledgers = [ledger('l-1'), ledger('l-2', sortOrder: 1)];

      final reconciled = QuickAddNameResolver.reconcileSelectedLedger(
        current: 'l-2',
        resolution: QuickAddAccountResolution.singleLedgerAuto,
        availableLedgers: ledgers,
        matchedContacts: const [],
      );

      expect(reconciled, 'l-2');
    });
  });
}
