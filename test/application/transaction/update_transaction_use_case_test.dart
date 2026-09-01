import 'dart:async';

import 'package:daftar/application/contact/check_credit_limit_use_case.dart';
import 'package:daftar/application/transaction/update_transaction_use_case.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/entities/contact.dart';
import 'package:daftar/domain/entities/ledger.dart';
import 'package:daftar/domain/entities/transaction.dart';
import 'package:daftar/domain/enums/ledger_type.dart';
import 'package:daftar/domain/enums/transaction_type.dart';
import 'package:daftar/domain/repositories/contact_repository.dart';
import 'package:daftar/domain/repositories/ledger_repository.dart';
import 'package:daftar/domain/repositories/transaction_repository.dart'
    as transaction_repository;
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockTransactionRepository extends Mock
    implements transaction_repository.TransactionRepository {}

class MockContactRepository extends Mock implements ContactRepository {}

class MockLedgerRepository extends Mock implements LedgerRepository {}

class MockCheckCreditLimitUseCase extends Mock
    implements CheckCreditLimitUseCase {}

void main() {
  late MockTransactionRepository transactionRepository;
  late MockContactRepository contactRepository;
  late MockLedgerRepository ledgerRepository;
  late MockCheckCreditLimitUseCase checkCreditLimitUseCase;

  setUpAll(() {
    registerFallbackValue(
      const transaction_repository.UpdateTransactionParams(id: 'fallback-id'),
    );
  });

  setUp(() {
    transactionRepository = MockTransactionRepository();
    contactRepository = MockContactRepository();
    ledgerRepository = MockLedgerRepository();
    checkCreditLimitUseCase = MockCheckCreditLimitUseCase();
  });

  UpdateTransactionUseCase buildUseCase() => UpdateTransactionUseCase(
    transactionRepository,
    contactRepository,
    ledgerRepository,
    checkCreditLimitUseCase,
  );

  void stubGuardChain({
    required String transactionId,
    required String contactId,
    required String ledgerId,
    required Transaction existingTransaction,
  }) {
    when(
      () => transactionRepository.getById(transactionId),
    ).thenAnswer((_) async => Right(existingTransaction));
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

  group('UpdateTransactionUseCase', () {
    test('returns success with no credit warning', () async {
      final useCase = buildUseCase();
      const transactionId = 'txn-1';
      const contactId = 'contact-1';
      const ledgerId = 'ledger-1';
      final updateDate = DateTime.utc(2026, 2, 6);
      final existingTransaction = Transaction(
        id: transactionId,
        contactId: contactId,
        type: TransactionType.debt,
        amount: 5000,
        currency: 'YER',
        transactionDate: DateTime.utc(2026, 2, 4),
        createdAt: DateTime.utc(2026, 2, 4),
        updatedAt: DateTime.utc(2026, 2, 4),
      );
      final updatedTransaction = Transaction(
        id: transactionId,
        contactId: contactId,
        type: TransactionType.debt,
        amount: 7900,
        currency: 'YER',
        transactionDate: updateDate,
        description: 'مراجعة الفاتورة',
        createdAt: DateTime.utc(2026, 2, 4),
        updatedAt: updateDate,
      );

      stubGuardChain(
        transactionId: transactionId,
        contactId: contactId,
        ledgerId: ledgerId,
        existingTransaction: existingTransaction,
      );
      when(
        () => transactionRepository.update(
          any<transaction_repository.UpdateTransactionParams>(),
        ),
      ).thenAnswer((_) async => Right(updatedTransaction));
      when(
        () => checkCreditLimitUseCase.execute(contactId),
      ).thenAnswer((_) async => const Right(CreditWarningLevel.none));

      final result = await useCase.execute(
        UpdateTransactionParams(
          id: '  txn-1  ',
          amount: 7900,
          type: TransactionType.debt,
          currency: ' yer ',
          description: '  مراجعة الفاتورة  ',
          transactionDate: updateDate,
        ),
      );

      final value = await expectRight(result);
      expect(value.transaction, updatedTransaction);
      expect(value.warningLevel, CreditWarningLevel.none);

      final captured =
          verify(
                () => transactionRepository.update(
                  captureAny<transaction_repository.UpdateTransactionParams>(),
                ),
              ).captured.single
              as transaction_repository.UpdateTransactionParams;
      expect(captured.id, transactionId);
      expect(captured.amount, 7900);
      expect(captured.type, TransactionType.debt);
      expect(captured.currency, 'YER');
      expect(captured.description, 'مراجعة الفاتورة');
      expect(captured.transactionDate, updateDate);

      verify(() => checkCreditLimitUseCase.execute(contactId)).called(1);
    });

    test('propagates warning level from checker', () async {
      final useCase = buildUseCase();
      const transactionId = 'txn-2';
      const contactId = 'contact-1';
      const ledgerId = 'ledger-1';
      final updateDate = DateTime.utc(2026, 2, 6);
      final existingTransaction = Transaction(
        id: transactionId,
        contactId: contactId,
        type: TransactionType.debt,
        amount: 5000,
        currency: 'YER',
        transactionDate: DateTime.utc(2026, 2, 4),
        createdAt: DateTime.utc(2026, 2, 4),
        updatedAt: DateTime.utc(2026, 2, 4),
      );
      final updatedTransaction = Transaction(
        id: transactionId,
        contactId: contactId,
        type: TransactionType.debt,
        amount: 8000,
        currency: 'YER',
        transactionDate: updateDate,
        createdAt: DateTime.utc(2026, 2, 4),
        updatedAt: updateDate,
      );

      stubGuardChain(
        transactionId: transactionId,
        contactId: contactId,
        ledgerId: ledgerId,
        existingTransaction: existingTransaction,
      );
      when(
        () => transactionRepository.update(
          any<transaction_repository.UpdateTransactionParams>(),
        ),
      ).thenAnswer((_) async => Right(updatedTransaction));
      when(
        () => checkCreditLimitUseCase.execute(contactId),
      ).thenAnswer((_) async => const Right(CreditWarningLevel.warning));

      final result = await useCase.execute(
        UpdateTransactionParams(
          id: transactionId,
          amount: 8000,
          type: TransactionType.debt,
          transactionDate: updateDate,
        ),
      );

      final value = await expectRight(result);
      expect(value.transaction, updatedTransaction);
      expect(value.warningLevel, CreditWarningLevel.warning);
      verify(() => checkCreditLimitUseCase.execute(contactId)).called(1);
    });

    test('propagates exceeded level from checker', () async {
      final useCase = buildUseCase();
      const transactionId = 'txn-3';
      const contactId = 'contact-1';
      const ledgerId = 'ledger-1';
      final updateDate = DateTime.utc(2026, 2, 6);
      final existingTransaction = Transaction(
        id: transactionId,
        contactId: contactId,
        type: TransactionType.debt,
        amount: 5000,
        currency: 'YER',
        transactionDate: DateTime.utc(2026, 2, 4),
        createdAt: DateTime.utc(2026, 2, 4),
        updatedAt: DateTime.utc(2026, 2, 4),
      );
      final updatedTransaction = Transaction(
        id: transactionId,
        contactId: contactId,
        type: TransactionType.debt,
        amount: 10100,
        currency: 'YER',
        transactionDate: updateDate,
        createdAt: DateTime.utc(2026, 2, 4),
        updatedAt: updateDate,
      );

      stubGuardChain(
        transactionId: transactionId,
        contactId: contactId,
        ledgerId: ledgerId,
        existingTransaction: existingTransaction,
      );
      when(
        () => transactionRepository.update(
          any<transaction_repository.UpdateTransactionParams>(),
        ),
      ).thenAnswer((_) async => Right(updatedTransaction));
      when(
        () => checkCreditLimitUseCase.execute(contactId),
      ).thenAnswer((_) async => const Right(CreditWarningLevel.exceeded));

      final result = await useCase.execute(
        UpdateTransactionParams(
          id: transactionId,
          amount: 10100,
          type: TransactionType.debt,
          transactionDate: updateDate,
        ),
      );

      final value = await expectRight(result);
      expect(value.transaction, updatedTransaction);
      expect(value.warningLevel, CreditWarningLevel.exceeded);
      verify(() => checkCreditLimitUseCase.execute(contactId)).called(1);
    });

    test('returns validation failure when amount is invalid', () async {
      final useCase = buildUseCase();

      final result = await useCase.execute(
        const UpdateTransactionParams(
          id: 'txn-1',
          amount: 0,
        ),
      );

      final failure = await expectLeft(result);
      expect(failure, isA<InvalidAmountFailure>());
      verifyNever(
        () => transactionRepository.update(
          any<transaction_repository.UpdateTransactionParams>(),
        ),
      );
      verifyNever(() => checkCreditLimitUseCase.execute(any()));
    });

    test('returns repository failure without post-operation checks', () async {
      final useCase = buildUseCase();
      const transactionId = 'txn-1';
      const contactId = 'contact-1';
      const ledgerId = 'ledger-1';
      final existingTransaction = Transaction(
        id: transactionId,
        contactId: contactId,
        type: TransactionType.debt,
        amount: 5000,
        currency: 'YER',
        transactionDate: DateTime.utc(2026, 2, 4),
        createdAt: DateTime.utc(2026, 2, 4),
        updatedAt: DateTime.utc(2026, 2, 4),
      );

      stubGuardChain(
        transactionId: transactionId,
        contactId: contactId,
        ledgerId: ledgerId,
        existingTransaction: existingTransaction,
      );
      when(
        () => transactionRepository.update(
          any<transaction_repository.UpdateTransactionParams>(),
        ),
      ).thenAnswer(
        (_) async => const Left(
          DatabaseFailure('update failed', code: 'database_error'),
        ),
      );

      final result = await useCase.execute(
        UpdateTransactionParams(
          id: transactionId,
          amount: 5000,
          type: TransactionType.debt,
          description: 'ملاحظات',
          transactionDate: DateTime.utc(2026, 2, 6),
        ),
      );

      final failure = await expectLeft(result);
      expect(failure, isA<DatabaseFailure>());
      verify(
        () => transactionRepository.update(
          any<transaction_repository.UpdateTransactionParams>(),
        ),
      ).called(1);
      verifyNever(() => checkCreditLimitUseCase.execute(any()));
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
