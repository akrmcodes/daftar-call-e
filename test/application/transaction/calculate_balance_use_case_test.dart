import 'dart:async';

import 'package:daftar/application/transaction/calculate_balance_use_case.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/entities/contact_balance.dart';
import 'package:daftar/domain/entities/transaction.dart';
import 'package:daftar/domain/enums/transaction_type.dart';
import 'package:daftar/domain/repositories/transaction_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockTransactionRepository extends Mock implements TransactionRepository {}

void main() {
  late MockTransactionRepository transactionRepository;

  setUp(() {
    transactionRepository = MockTransactionRepository();
  });

  group('CalculateBalanceUseCase', () {
    test('returns exact balances for multiple currencies', () async {
      final useCase = CalculateBalanceUseCase(transactionRepository);
      const contactId = 'contact-1';
      final transactions = [
        Transaction(
          id: 't1',
          contactId: contactId,
          type: TransactionType.debt,
          amount: 1500,
          currency: 'YER',
          transactionDate: DateTime.utc(2026, 2, 6),
          createdAt: DateTime.utc(2026, 2, 6),
          updatedAt: DateTime.utc(2026, 2, 6),
        ),
        Transaction(
          id: 't2',
          contactId: contactId,
          type: TransactionType.payment,
          amount: 350,
          currency: 'YER',
          transactionDate: DateTime.utc(2026, 2, 7),
          createdAt: DateTime.utc(2026, 2, 7),
          updatedAt: DateTime.utc(2026, 2, 7),
        ),
        Transaction(
          id: 't3',
          contactId: contactId,
          type: TransactionType.payment,
          amount: 100,
          currency: 'USD',
          transactionDate: DateTime.utc(2026, 2, 7),
          createdAt: DateTime.utc(2026, 2, 7),
          updatedAt: DateTime.utc(2026, 2, 7),
        ),
        Transaction(
          id: 't4',
          contactId: contactId,
          type: TransactionType.debt,
          amount: 25,
          currency: 'USD',
          transactionDate: DateTime.utc(2026, 2, 8),
          createdAt: DateTime.utc(2026, 2, 8),
          updatedAt: DateTime.utc(2026, 2, 8),
        ),
      ];

      when(
        () => transactionRepository.getRawTransactionsByContact(contactId),
      ).thenAnswer((_) async => Right(transactions));

      final result = await useCase.execute(
        const CalculateBalanceParams(contactId: contactId),
      );

      final balances = await expectRight(result);
      expect(balances, hasLength(2));
      expect(
        balances,
        [
          isA<ContactBalance>()
              .having((balance) => balance.currencyCode, 'currencyCode', 'USD')
              .having((balance) => balance.totalDebt, 'totalDebt', 25)
              .having((balance) => balance.totalPayment, 'totalPayment', 100)
              .having((balance) => balance.netBalance, 'netBalance', 75)
              .having((balance) => balance.contactId, 'contactId', contactId),
          isA<ContactBalance>()
              .having((balance) => balance.currencyCode, 'currencyCode', 'YER')
              .having((balance) => balance.totalDebt, 'totalDebt', 1500)
              .having((balance) => balance.totalPayment, 'totalPayment', 350)
              .having((balance) => balance.netBalance, 'netBalance', -1150)
              .having((balance) => balance.contactId, 'contactId', contactId),
        ],
      );

      verify(
        () => transactionRepository.getRawTransactionsByContact(contactId),
      ).called(1);
    });

    test('returns empty list for zero transactions', () async {
      final useCase = CalculateBalanceUseCase(transactionRepository);
      const contactId = 'contact-empty';

      when(
        () => transactionRepository.getRawTransactionsByContact(contactId),
      ).thenAnswer((_) async => const Right(<Transaction>[]));

      final result = await useCase.execute(
        const CalculateBalanceParams(contactId: contactId),
      );

      final balances = await expectRight(result);
      expect(balances, isEmpty);
      verify(
        () => transactionRepository.getRawTransactionsByContact(contactId),
      ).called(1);
    });

    test('maps repository failure as-is', () async {
      final useCase = CalculateBalanceUseCase(transactionRepository);
      const contactId = 'contact-error';

      when(
        () => transactionRepository.getRawTransactionsByContact(contactId),
      ).thenAnswer(
        (_) async => const Left(
          DatabaseFailure('lookup failed', code: 'database_error'),
        ),
      );

      final result = await useCase.execute(
        const CalculateBalanceParams(contactId: contactId),
      );

      final failure = await expectLeft(result);
      expect(failure, isA<DatabaseFailure>());
      verify(
        () => transactionRepository.getRawTransactionsByContact(contactId),
      ).called(1);
    });
  });
}

Future<T> expectRight<T>(FutureOr<Either<Failure, T>> resultOrFuture) async {
  final result = await resultOrFuture;
  return result.fold(
    (failure) => fail('Expected Right but got Left($failure)'),
    (value) => value,
  );
}

Future<Failure> expectLeft<T>(
  FutureOr<Either<Failure, T>> resultOrFuture,
) async {
  final result = await resultOrFuture;
  return result.fold(
    (failure) => failure,
    (value) => fail('Expected Left but got Right($value)'),
  );
}
