import 'package:daftar/application/transaction/quick_add_state.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/entities/contact.dart';
import 'package:daftar/domain/entities/ledger.dart';
import 'package:daftar/domain/enums/ledger_type.dart';
import 'package:daftar/domain/enums/transaction_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 6);

  Ledger ledger({
    required String id,
    required String name,
    int sortOrder = 0,
  }) {
    return Ledger(
      id: id,
      name: name,
      type: LedgerType.custom,
      icon: 'folder',
      color: '#000000',
      sortOrder: sortOrder,
      createdAt: now,
      updatedAt: now,
    );
  }

  Contact contact({
    required String id,
    required String ledgerId,
    required String name,
  }) {
    return Contact(
      id: id,
      ledgerId: ledgerId,
      name: name,
      avatarColor: '#5C6BC0',
      createdAt: now,
      updatedAt: now,
    );
  }

  group('QuickAddState', () {
    test('initial selects primary ledger and normalizes currency', () {
      final ledgers = [
        ledger(id: 'l-2', name: 'B', sortOrder: 1),
        ledger(id: 'l-1', name: 'A'),
      ];

      final state = QuickAddState.initial(
        availableLedgers: ledgers,
        defaultCurrency: ' yer ',
      );

      expect(state.selectedLedgerId, 'l-1');
      expect(state.selectedCurrencyCode, 'YER');
      expect(state.accountResolution, QuickAddAccountResolution.idle);
      expect(state.transactionType, TransactionType.debt);
    });

    test('primaryLedgerId returns null for empty ledgers', () {
      expect(QuickAddState.primaryLedgerId(const []), isNull);
    });

    test('primaryLedgerId breaks sortOrder ties by name', () {
      final ledgers = [
        ledger(id: 'l-b', name: 'Beta'),
        ledger(id: 'l-a', name: 'Alpha'),
      ];

      expect(QuickAddState.primaryLedgerId(ledgers), 'l-a');
    });

    test('showContactSuggestions is false while searching', () {
      final state = QuickAddState.initial(
        availableLedgers: [ledger(id: 'l-1', name: 'A')],
      ).copyWith(
        isSearchingName: true,
        matchedContacts: [contact(id: 'c-1', ledgerId: 'l-1', name: 'Ali')],
      );

      expect(state.showContactSuggestions, isFalse);
    });

    test('showContactSuggestions is false when contact already selected', () {
      final state = QuickAddState.initial(
        availableLedgers: [ledger(id: 'l-1', name: 'A')],
      ).copyWith(
        matchedContacts: [contact(id: 'c-1', ledgerId: 'l-1', name: 'Ali')],
        selectedContactId: 'c-1',
      );

      expect(state.showContactSuggestions, isFalse);
    });

    test('showContactSuggestions is false for single exact name match', () {
      final state = QuickAddState.initial(
        availableLedgers: [ledger(id: 'l-1', name: 'A')],
      ).copyWith(
        nameQuery: '  Ali ',
        matchedContacts: [contact(id: 'c-1', ledgerId: 'l-1', name: 'Ali')],
      );

      expect(state.showContactSuggestions, isFalse);
    });

    test('ledgersForPicker filters to match ledgers in multi pick mode', () {
      final ledgers = [
        ledger(id: 'l-1', name: 'A'),
        ledger(id: 'l-2', name: 'B'),
        ledger(id: 'l-3', name: 'C'),
      ];
      final state = QuickAddState.initial(availableLedgers: ledgers).copyWith(
        accountResolution: QuickAddAccountResolution.multiLedgerPick,
        matchedContacts: [
          contact(id: 'c-1', ledgerId: 'l-1', name: 'A'),
          contact(id: 'c-2', ledgerId: 'l-2', name: 'B'),
        ],
      );

      final pickerIds = state.ledgersForPicker.map((l) => l.id).toList();
      expect(pickerIds, ['l-1', 'l-2']);
    });

    test('copyWith clear flags reset nullable fields', () {
      final state = QuickAddState.initial(
        availableLedgers: [ledger(id: 'l-1', name: 'A')],
      ).copyWith(
        amountMinorUnits: 500,
        selectedContactId: 'c-1',
        searchFailure: const DatabaseFailure('x'),
      );

      final cleared = state.copyWith(
        clearAmount: true,
        clearSelectedContactId: true,
        clearSearchFailure: true,
        clearSelectedLedgerId: true,
      );

      expect(cleared.amountMinorUnits, isNull);
      expect(cleared.selectedContactId, isNull);
      expect(cleared.searchFailure, isNull);
      expect(cleared.selectedLedgerId, isNull);
    });

    test('isCredit reflects payment transaction type', () {
      final state = QuickAddState.initial(
        availableLedgers: [ledger(id: 'l-1', name: 'A')],
      ).copyWith(transactionType: TransactionType.payment);

      expect(state.isCredit, isTrue);
      expect(state.isNewAccount, isFalse);
    });
  });
}
