import 'dart:async';

import 'package:daftar/application/transaction/get_transactions_use_case.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/entities/transaction.dart';
import 'package:daftar/domain/enums/transaction_type.dart';
import 'package:daftar/domain/repositories/transaction_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockTransactionRepository extends Mock implements TransactionRepository {}

void main() {
  late MockTransactionRepository transactionRepository;

  setUp(() {
    transactionRepository = MockTransactionRepository();
  });

  group('GetTransactionsUseCase', () {
    test('returns repository stream with default pagination', () async {
      final useCase = GetTransactionsUseCase(transactionRepository);
      const contactId = 'contact-1';
      final transactions = [
        _transaction(
          id: 'txn-1',
          contactId: contactId,
          type: TransactionType.debt,
          amount: 1000,
          currency: 'YER',
        ),
        _transaction(
          id: 'txn-2',
          contactId: contactId,
          type: TransactionType.payment,
          amount: 250,
          currency: 'YER',
        ),
      ];

      when(
        () => transactionRepository.watchTransactions(
          contactId,
        ),
      ).thenAnswer((_) => Stream.value(transactions));

      await expectLater(
        useCase.execute(const GetTransactionsParams(contactId: contactId)),
        emits(transactions),
      );

      verify(
        () => transactionRepository.watchTransactions(
          contactId,
        ),
      ).called(1);
    });

    test('forwards custom pagination and date filters', () async {
      final useCase = GetTransactionsUseCase(transactionRepository);
      const contactId = 'contact-1';
      final startDate = DateTime.utc(2026, 2);
      final endDate = DateTime.utc(2026, 2, 28);
      final transactions = [
        _transaction(
          id: 'txn-3',
          contactId: contactId,
          type: TransactionType.debt,
          amount: 500,
          currency: 'USD',
        ),
      ];

      when(
        () => transactionRepository.watchTransactions(
          contactId,
          limit: 7,
          offset: 14,
          startDate: startDate,
          endDate: endDate,
        ),
      ).thenAnswer((_) => Stream.value(transactions));

      await expectLater(
        useCase.execute(
          GetTransactionsParams(
            contactId: '  $contactId  ',
            limit: 7,
            offset: 14,
            startDate: startDate,
            endDate: endDate,
          ),
        ),
        emits(transactions),
      );

      verify(
        () => transactionRepository.watchTransactions(
          contactId,
          limit: 7,
          offset: 14,
          startDate: startDate,
          endDate: endDate,
        ),
      ).called(1);
    });

    test('returns an error stream for an invalid date range', () async {
      final useCase = GetTransactionsUseCase(transactionRepository);
      final startDate = DateTime.utc(2026, 2, 28);
      final endDate = DateTime.utc(2026, 2);

      final stream = useCase.execute(
        GetTransactionsParams(
          contactId: 'contact-1',
          startDate: startDate,
          endDate: endDate,
        ),
      );

      await expectLater(stream, emitsError(isA<ValidationFailure>()));
      verifyNever(
        () => transactionRepository.watchTransactions(
          'contact-1',
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      );
    });
  });
}

Transaction _transaction({
  required String id,
  required String contactId,
  required TransactionType type,
  required int amount,
  required String currency,
}) {
  final timestamp = DateTime.utc(2026, 2, 6);
  return Transaction(
    id: id,
    contactId: contactId,
    type: type,
    amount: amount,
    currency: currency,
    transactionDate: timestamp,
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}
