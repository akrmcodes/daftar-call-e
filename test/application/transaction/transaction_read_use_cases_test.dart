import 'package:daftar/application/transaction/get_all_transactions_for_contact_use_case.dart';
import 'package:daftar/core/errors/failures.dart';
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

  group('GetAllTransactionsForContactUseCase', () {
    test('returns ValidationFailure when contact id is empty', () async {
      final sut = GetAllTransactionsForContactUseCase(transactionRepository);

      final result = await sut.execute('  ');

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure.code, 'transaction_contact_required'),
        (_) => fail('expected failure'),
      );
      verifyNever(() => transactionRepository.getRawTransactionsByContact(any()));
    });

    test('delegates trimmed contact id to repository', () async {
      final sut = GetAllTransactionsForContactUseCase(transactionRepository);
      final now = DateTime.utc(2026, 6);
      final transactions = [
        Transaction(
          id: 'txn-1',
          contactId: 'contact-1',
          type: TransactionType.debt,
          amount: 100,
          currency: 'YER',
          transactionDate: now,
          createdAt: now,
          updatedAt: now,
        ),
      ];
      when(
        () => transactionRepository.getRawTransactionsByContact('contact-1'),
      ).thenAnswer((_) async => Right(transactions));

      final result = await sut.execute('  contact-1  ');

      expect(result, Right<Failure, List<Transaction>>(transactions));
    });

    test('returns repository failure', () async {
      final sut = GetAllTransactionsForContactUseCase(transactionRepository);
      when(
        () => transactionRepository.getRawTransactionsByContact('contact-1'),
      ).thenAnswer(
        (_) async => const Left(DatabaseFailure('read failed')),
      );

      final result = await sut.execute('contact-1');

      expect(result.isLeft(), isTrue);
    });
  });
}
