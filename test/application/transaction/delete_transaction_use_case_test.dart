import 'dart:async';

import 'package:daftar/application/transaction/delete_transaction_use_case.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/entities/contact.dart';
import 'package:daftar/domain/entities/ledger.dart';
import 'package:daftar/domain/entities/transaction.dart';
import 'package:daftar/domain/enums/ledger_type.dart';
import 'package:daftar/domain/enums/transaction_type.dart';
import 'package:daftar/domain/repositories/contact_repository.dart';
import 'package:daftar/domain/repositories/ledger_repository.dart';
import 'package:daftar/domain/repositories/transaction_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockTransactionRepository extends Mock implements TransactionRepository {}

class MockContactRepository extends Mock implements ContactRepository {}

class MockLedgerRepository extends Mock implements LedgerRepository {}

void main() {
  late MockTransactionRepository transactionRepository;
  late MockContactRepository contactRepository;
  late MockLedgerRepository ledgerRepository;

  setUp(() {
    transactionRepository = MockTransactionRepository();
    contactRepository = MockContactRepository();
    ledgerRepository = MockLedgerRepository();
  });

  DeleteTransactionUseCase buildUseCase() => DeleteTransactionUseCase(
    transactionRepository,
    contactRepository,
    ledgerRepository,
  );

  void stubGuardChain({
    required String transactionId,
    required String contactId,
    required String ledgerId,
  }) {
    when(
      () => transactionRepository.getById(transactionId),
    ).thenAnswer(
      (_) async => Right(
        Transaction(
          id: transactionId,
          contactId: contactId,
          type: TransactionType.debt,
          amount: 5000,
          currency: 'YER',
          transactionDate: DateTime.utc(2026, 2, 4),
          createdAt: DateTime.utc(2026, 2, 4),
          updatedAt: DateTime.utc(2026, 2, 4),
        ),
      ),
    );
    when(
      () => contactRepository.getById(contactId),
    ).thenAnswer(
      (_) async => Right(
        Contact(
          id: contactId,
          ledgerId: ledgerId,
          name: 'عميل',
          avatarColor: '#5C6BC0',
          createdAt: DateTime.utc(2026, 2, 3),
          updatedAt: DateTime.utc(2026, 2, 4),
        ),
      ),
    );
    when(
      () => ledgerRepository.getById(ledgerId),
    ).thenAnswer(
      (_) async => Right(
        Ledger(
          id: ledgerId,
          name: 'دفتر',
          type: LedgerType.custom,
          icon: 'folder',
          color: '#5C6BC0',
          sortOrder: 0,
          createdAt: DateTime.utc(2026, 2, 3),
          updatedAt: DateTime.utc(2026, 2, 4),
        ),
      ),
    );
  }

  group('DeleteTransactionUseCase', () {
    test('returns success and forwards normalized id', () async {
      final useCase = buildUseCase();
      stubGuardChain(
        transactionId: 'txn-1',
        contactId: 'contact-1',
        ledgerId: 'ledger-1',
      );

      when(
        () => transactionRepository.deleteTransaction('txn-1'),
      ).thenAnswer((_) async => const Right(unit));

      final result = await useCase.execute(
        const DeleteTransactionParams(id: '  txn-1  '),
      );

      final value = await expectRight(result);
      expect(value, unit);

      verify(() => transactionRepository.deleteTransaction('txn-1')).called(1);
    });

    test('returns validation failure for empty id', () async {
      final useCase = buildUseCase();

      final result = await useCase.execute(
        const DeleteTransactionParams(id: '   '),
      );

      final failure = await expectLeft(result);
      expect(failure, isA<ValidationFailure>());
      verifyNever(() => transactionRepository.deleteTransaction(any()));
    });

    test('maps repository failure as-is', () async {
      final useCase = buildUseCase();
      stubGuardChain(
        transactionId: 'txn-1',
        contactId: 'contact-1',
        ledgerId: 'ledger-1',
      );

      when(
        () => transactionRepository.deleteTransaction('txn-1'),
      ).thenAnswer(
        (_) async => const Left(
          DatabaseFailure('delete failed', code: 'database_error'),
        ),
      );

      final result = await useCase.execute(
        const DeleteTransactionParams(id: 'txn-1'),
      );

      final failure = await expectLeft(result);
      expect(failure, isA<DatabaseFailure>());
      verify(() => transactionRepository.deleteTransaction('txn-1')).called(1);
    });

    test('returns transaction repository failure before delete', () async {
      final useCase = buildUseCase();
      when(() => transactionRepository.getById('txn-1')).thenAnswer(
        (_) async => const Left(DatabaseFailure('missing txn')),
      );

      final result = await useCase.execute(
        const DeleteTransactionParams(id: 'txn-1'),
      );

      final failure = await expectLeft(result);
      expect(failure, isA<DatabaseFailure>());
      verifyNever(() => transactionRepository.deleteTransaction(any()));
    });

    test('returns contact repository failure', () async {
      final useCase = buildUseCase();
      when(() => transactionRepository.getById('txn-1')).thenAnswer(
        (_) async => Right(
          Transaction(
            id: 'txn-1',
            contactId: 'contact-1',
            type: TransactionType.debt,
            amount: 5000,
            currency: 'YER',
            transactionDate: DateTime.utc(2026, 2, 4),
            createdAt: DateTime.utc(2026, 2, 4),
            updatedAt: DateTime.utc(2026, 2, 4),
          ),
        ),
      );
      when(() => contactRepository.getById('contact-1')).thenAnswer(
        (_) async => const Left(DatabaseFailure('contact missing')),
      );

      final result = await useCase.execute(
        const DeleteTransactionParams(id: 'txn-1'),
      );

      final failure = await expectLeft(result);
      expect(failure, isA<DatabaseFailure>());
      verifyNever(() => transactionRepository.deleteTransaction(any()));
    });

    test('returns ledger repository failure', () async {
      final useCase = buildUseCase();
      stubGuardChain(
        transactionId: 'txn-1',
        contactId: 'contact-1',
        ledgerId: 'ledger-1',
      );
      when(() => ledgerRepository.getById('ledger-1')).thenAnswer(
        (_) async => const Left(DatabaseFailure('ledger missing')),
      );

      final result = await useCase.execute(
        const DeleteTransactionParams(id: 'txn-1'),
      );

      final failure = await expectLeft(result);
      expect(failure, isA<DatabaseFailure>());
      verifyNever(() => transactionRepository.deleteTransaction(any()));
    });

    test('returns validation failure when ledger is user-archived', () async {
      final useCase = buildUseCase();
      stubGuardChain(
        transactionId: 'txn-1',
        contactId: 'contact-1',
        ledgerId: 'ledger-1',
      );
      when(() => ledgerRepository.getById('ledger-1')).thenAnswer(
        (_) async => Right(
          Ledger(
            id: 'ledger-1',
            name: 'Archived',
            type: LedgerType.custom,
            icon: 'folder',
            color: '#000000',
            sortOrder: 0,
            isUserArchived: true,
            createdAt: DateTime.utc(2026, 2, 3),
            updatedAt: DateTime.utc(2026, 2, 4),
          ),
        ),
      );

      final result = await useCase.execute(
        const DeleteTransactionParams(id: 'txn-1'),
      );

      final failure = await expectLeft(result);
      expect(failure, isA<ValidationFailure>());
      verifyNever(() => transactionRepository.deleteTransaction(any()));
    });

    test('maps unexpected exceptions to DatabaseFailure', () async {
      final useCase = buildUseCase();
      when(() => transactionRepository.getById('txn-1')).thenThrow(
        Exception('unexpected'),
      );

      final result = await useCase.execute(
        const DeleteTransactionParams(id: 'txn-1'),
      );

      final failure = await expectLeft(result);
      expect(failure, isA<DatabaseFailure>());
      expect(failure.code, 'database_error');
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
