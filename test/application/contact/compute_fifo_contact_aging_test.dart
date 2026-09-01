import 'package:daftar/application/contact/compute_fifo_contact_aging.dart';
import 'package:daftar/domain/constants/reminder_tone_resolver.dart';
import 'package:daftar/domain/entities/transaction.dart';
import 'package:daftar/domain/enums/reminder_tone_band.dart';
import 'package:daftar/domain/enums/transaction_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Frozen merchant local day for Stage 3.2 fixtures.
  final asOf = DateTime(2026, 8, 14);

  Transaction txn({
    required String id,
    required TransactionType type,
    required int amount,
    required DateTime date,
    String currency = 'YER',
  }) {
    return Transaction(
      id: id,
      contactId: 'contact-mohamed',
      type: type,
      amount: amount,
      currency: currency,
      transactionDate: date,
      createdAt: date,
      updatedAt: date,
    );
  }

  group('reminderToneBandForAgeDays', () {
    test('friendly under 7, reminder from 7, firm from 30', () {
      expect(reminderToneBandForAgeDays(0), ReminderToneBand.friendly);
      expect(reminderToneBandForAgeDays(3), ReminderToneBand.friendly);
      expect(reminderToneBandForAgeDays(6), ReminderToneBand.friendly);
      expect(reminderToneBandForAgeDays(7), ReminderToneBand.reminder);
      expect(reminderToneBandForAgeDays(29), ReminderToneBand.reminder);
      expect(reminderToneBandForAgeDays(30), ReminderToneBand.firm);
      expect(reminderToneBandForAgeDays(40), ReminderToneBand.firm);
    });
  });

  group('computeFifoContactAging', () {
    test('Mohamed 100 then +50: outstanding 150, age 40, firm', () {
      final result = computeFifoContactAging(
        transactions: [
          txn(
            id: 'd-100',
            type: TransactionType.debt,
            amount: 100,
            date: DateTime(2026, 7, 5),
          ),
          txn(
            id: 'd-50',
            type: TransactionType.debt,
            amount: 50,
            date: DateTime(2026, 8, 4),
          ),
        ],
        currencyCode: 'YER',
        asOf: asOf,
      );

      expect(result, isNotNull);
      expect(result!.openMinor, 150);
      expect(result.ageDays, 40);
      expect(result.toneBand, ReminderToneBand.firm);
      expect(result.daysSinceLastPayment, isNull);
      expect(result.daysSinceLastDebt, 10);
    });

    test('old FIFO remainder with recent payment caps tone to reminder', () {
      final result = computeFifoContactAging(
        transactions: [
          txn(
            id: 'd-100',
            type: TransactionType.debt,
            amount: 100,
            date: DateTime(2026, 7, 5),
          ),
          txn(
            id: 'd-50',
            type: TransactionType.debt,
            amount: 50,
            date: DateTime(2026, 8, 4),
          ),
          txn(
            id: 'p-20',
            type: TransactionType.payment,
            amount: 20,
            date: DateTime(2026, 8, 12),
          ),
        ],
        currencyCode: 'YER',
        asOf: asOf,
      );

      expect(result, isNotNull);
      expect(result!.openMinor, 130);
      expect(result.ageDays, 40);
      expect(result.daysSinceLastPayment, 2);
      expect(result.toneBand, ReminderToneBand.reminder);
    });

    test('FIFO payment 100 consumes first debt; remaining 50 aged 10', () {
      final result = computeFifoContactAging(
        transactions: [
          txn(
            id: 'd-100',
            type: TransactionType.debt,
            amount: 100,
            date: DateTime(2026, 7, 5),
          ),
          txn(
            id: 'd-50',
            type: TransactionType.debt,
            amount: 50,
            date: DateTime(2026, 8, 4),
          ),
          txn(
            id: 'p-100',
            type: TransactionType.payment,
            amount: 100,
            date: DateTime(2026, 8, 9),
          ),
        ],
        currencyCode: 'YER',
        asOf: asOf,
      );

      expect(result, isNotNull);
      expect(result!.openMinor, 50);
      expect(result.ageDays, 10);
      expect(result.toneBand, ReminderToneBand.reminder);
      expect(result.daysSinceLastPayment, 5);
      expect(result.daysSinceLastDebt, 10);
    });

    test('friendly bound: D-3 debt 100', () {
      final result = computeFifoContactAging(
        transactions: [
          txn(
            id: 'd-100',
            type: TransactionType.debt,
            amount: 100,
            date: DateTime(2026, 8, 11),
          ),
        ],
        currencyCode: 'YER',
        asOf: asOf,
      );

      expect(result!.openMinor, 100);
      expect(result.ageDays, 3);
      expect(result.toneBand, ReminderToneBand.friendly);
    });

    test('reminder bound: D-7 debt 100', () {
      final result = computeFifoContactAging(
        transactions: [
          txn(
            id: 'd-100',
            type: TransactionType.debt,
            amount: 100,
            date: DateTime(2026, 8, 7),
          ),
        ],
        currencyCode: 'YER',
        asOf: asOf,
      );

      expect(result!.ageDays, 7);
      expect(result.toneBand, ReminderToneBand.reminder);
    });

    test('firm bound: D-30 debt 100', () {
      final result = computeFifoContactAging(
        transactions: [
          txn(
            id: 'd-100',
            type: TransactionType.debt,
            amount: 100,
            date: DateTime(2026, 7, 15),
          ),
        ],
        currencyCode: 'YER',
        asOf: asOf,
      );

      expect(result!.ageDays, 30);
      expect(result.toneBand, ReminderToneBand.firm);
    });

    test('fully paid timeline is not overdue', () {
      final result = computeFifoContactAging(
        transactions: [
          txn(
            id: 'd-100',
            type: TransactionType.debt,
            amount: 100,
            date: DateTime(2026, 7, 5),
          ),
          txn(
            id: 'p-100',
            type: TransactionType.payment,
            amount: 100,
            date: DateTime(2026, 8, 9),
          ),
        ],
        currencyCode: 'YER',
        asOf: asOf,
      );

      expect(result, isNull);
    });

    test('does not mix currencies', () {
      final result = computeFifoContactAging(
        transactions: [
          txn(
            id: 'd-yer',
            type: TransactionType.debt,
            amount: 100,
            date: DateTime(2026, 7, 5),
          ),
          txn(
            id: 'p-sar',
            type: TransactionType.payment,
            amount: 100,
            date: DateTime(2026, 8, 9),
            currency: 'SAR',
          ),
        ],
        currencyCode: 'YER',
        asOf: asOf,
      );

      expect(result!.openMinor, 100);
      expect(result.ageDays, 40);
    });

    test('partial payment leaves remainder on oldest debt', () {
      final result = computeFifoContactAging(
        transactions: [
          txn(
            id: 'd-100',
            type: TransactionType.debt,
            amount: 100,
            date: DateTime(2026, 7, 5),
          ),
          txn(
            id: 'p-40',
            type: TransactionType.payment,
            amount: 40,
            date: DateTime(2026, 8, 9),
          ),
        ],
        currencyCode: 'YER',
        asOf: asOf,
      );

      expect(result!.openMinor, 60);
      expect(result.ageDays, 40);
    });

    test('same-day order uses createdAt then id', () {
      final day = DateTime(2026, 8, 4);
      final earlyCreated = DateTime(2026, 8, 4, 8);
      final lateCreated = DateTime(2026, 8, 4, 18);
      final result = computeFifoContactAging(
        transactions: [
          Transaction(
            id: 'd-b',
            contactId: 'contact-mohamed',
            type: TransactionType.debt,
            amount: 50,
            currency: 'YER',
            transactionDate: day,
            createdAt: lateCreated,
            updatedAt: lateCreated,
          ),
          Transaction(
            id: 'd-a',
            contactId: 'contact-mohamed',
            type: TransactionType.debt,
            amount: 100,
            currency: 'YER',
            transactionDate: day,
            createdAt: earlyCreated,
            updatedAt: earlyCreated,
          ),
          Transaction(
            id: 'p-100',
            contactId: 'contact-mohamed',
            type: TransactionType.payment,
            amount: 100,
            currency: 'YER',
            transactionDate: day,
            createdAt: lateCreated.add(const Duration(minutes: 1)),
            updatedAt: lateCreated,
          ),
        ],
        currencyCode: 'YER',
        asOf: asOf,
      );

      expect(result!.openMinor, 50);
      expect(result.ageDays, 10);
    });
  });
}
