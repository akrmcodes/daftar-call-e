import 'dart:async';

import 'package:daftar/application/contact/check_credit_limit_use_case.dart';
import 'package:daftar/application/contact/create_contact_use_case.dart';
import 'package:daftar/application/contact/delete_contact_use_case.dart';
import 'package:daftar/application/contact/update_contact_use_case.dart';
import 'package:daftar/application/ledger/update_ledger_use_case.dart';
import 'package:daftar/application/transaction/add_transaction_use_case.dart';
import 'package:daftar/application/transaction/delete_transaction_use_case.dart';
import 'package:daftar/application/transaction/update_transaction_use_case.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/entities/contact.dart';
import 'package:daftar/domain/entities/entitlement.dart';
import 'package:daftar/domain/entities/ledger.dart';
import 'package:daftar/domain/entities/transaction.dart';
import 'package:daftar/domain/enums/ledger_type.dart';
import 'package:daftar/domain/enums/transaction_type.dart';
import 'package:daftar/domain/repositories/activation_repository.dart';
import 'package:daftar/domain/repositories/contact_repository.dart';
import 'package:daftar/domain/repositories/ledger_repository.dart';
import 'package:daftar/domain/repositories/transaction_repository.dart'
    as txn_repo;
import 'package:daftar/domain/repositories/transaction_repository.dart'
    hide UpdateTransactionParams;
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockTransactionRepository extends Mock implements TransactionRepository {}

class MockContactRepository extends Mock implements ContactRepository {}

class MockLedgerRepository extends Mock implements LedgerRepository {}

class MockCheckCreditLimitUseCase extends Mock
    implements CheckCreditLimitUseCase {}

class MockActivationRepository extends Mock implements ActivationRepository {}

void main() {
  late MockTransactionRepository transactionRepository;
  late MockContactRepository contactRepository;
  late MockLedgerRepository ledgerRepository;
  late MockCheckCreditLimitUseCase checkCreditLimitUseCase;
  late MockActivationRepository activationRepository;

  const contactId = 'contact-1';
  const ledgerId = 'ledger-1';
  const transactionId = 'txn-1';

  setUpAll(() {
    registerFallbackValue(
      CreateTransactionParams(
        contactId: contactId,
        type: TransactionType.debt,
        amount: 1000,
        currency: 'YER',
        transactionDate: DateTime.utc(2026, 3),
      ),
    );
    registerFallbackValue(
      const CreateContactParams(
        ledgerId: ledgerId,
        name: 'عميل',
        avatarColor: '#5C6BC0',
      ),
    );
    registerFallbackValue(
      const UpdateContactParams(id: contactId),
    );
    registerFallbackValue(
      const UpdateLedgerParams(id: ledgerId),
    );
    registerFallbackValue(
      const txn_repo.UpdateTransactionParams(id: transactionId),
    );
    registerFallbackValue(
      const DeleteTransactionParams(id: transactionId),
    );
    registerFallbackValue(
      Contact(
        id: contactId,
        ledgerId: ledgerId,
        name: 'عميل',
        avatarColor: '#5C6BC0',
        createdAt: DateTime.utc(2026, 3),
        updatedAt: DateTime.utc(2026, 3, 2),
      ),
    );
  });

  setUp(() {
    transactionRepository = MockTransactionRepository();
    contactRepository = MockContactRepository();
    ledgerRepository = MockLedgerRepository();
    checkCreditLimitUseCase = MockCheckCreditLimitUseCase();
    activationRepository = MockActivationRepository();
    when(() => activationRepository.getEntitlement()).thenAnswer(
      (_) async => Entitlement.defaultFree(),
    );
  });

  Ledger userArchivedLedger() => Ledger(
    id: ledgerId,
    name: 'دفتر مؤرشف',
    type: LedgerType.custom,
    icon: 'archive',
    color: '#424242',
    sortOrder: 0,
    createdAt: DateTime.utc(2026, 3),
    updatedAt: DateTime.utc(2026, 3, 2),
    isUserArchived: true,
  );

  Ledger importArchivedLedger() => Ledger(
    id: ledgerId,
    name: 'دفتر استيراد',
    type: LedgerType.custom,
    icon: 'folder',
    color: '#424242',
    sortOrder: 0,
    createdAt: DateTime.utc(2026, 3),
    updatedAt: DateTime.utc(2026, 3, 2),
    isArchived: true,
  );

  Contact contact() => Contact(
    id: contactId,
    ledgerId: ledgerId,
    name: 'عميل',
    avatarColor: '#5C6BC0',
    createdAt: DateTime.utc(2026, 3),
    updatedAt: DateTime.utc(2026, 3, 2),
  );

  Transaction transaction() => Transaction(
    id: transactionId,
    contactId: contactId,
    type: TransactionType.debt,
    amount: 5000,
    currency: 'YER',
    transactionDate: DateTime.utc(2026, 3),
    createdAt: DateTime.utc(2026, 3),
    updatedAt: DateTime.utc(2026, 3, 2),
  );

  void stubArchivedLedgerChain() {
    when(() => contactRepository.getById(any())).thenAnswer(
      (_) async => Right(contact()),
    );
    when(() => ledgerRepository.getById(any())).thenAnswer(
      (_) async => Right(userArchivedLedger()),
    );
    when(() => transactionRepository.getById(any())).thenAnswer(
      (_) async => Right(transaction()),
    );
  }

  group('ledger_archived guard', () {
    test('AddTransactionUseCase blocks before create', () async {
      stubArchivedLedgerChain();

      final failure = await expectLeft(
        AddTransactionUseCase(
          transactionRepository,
          contactRepository,
          ledgerRepository,
          checkCreditLimitUseCase,
          activationRepository,
        ).execute(
          contactId: contactId,
          type: TransactionType.debt,
          amount: 1000,
          currency: 'YER',
        ),
      );

      expect(failure, isA<ValidationFailure>());
      expect(failure.code, 'ledger_archived');
      verifyNever(() => transactionRepository.create(any()));
    });

    test('UpdateTransactionUseCase blocks before update', () async {
      stubArchivedLedgerChain();

      final failure = await expectLeft(
        UpdateTransactionUseCase(
          transactionRepository,
          contactRepository,
          ledgerRepository,
          checkCreditLimitUseCase,
        ).execute(const UpdateTransactionParams(id: transactionId, amount: 2000)),
      );

      expect(failure.code, 'ledger_archived');
      verifyNever(
        () => transactionRepository.update(any<txn_repo.UpdateTransactionParams>()),
      );
    });

    test('DeleteTransactionUseCase blocks before delete', () async {
      stubArchivedLedgerChain();

      final failure = await expectLeft(
        DeleteTransactionUseCase(
          transactionRepository,
          contactRepository,
          ledgerRepository,
        ).execute(const DeleteTransactionParams(id: transactionId)),
      );

      expect(failure.code, 'ledger_archived');
      verifyNever(() => transactionRepository.deleteTransaction(any()));
    });

    test('CreateContactUseCase blocks before create', () async {
      stubArchivedLedgerChain();

      final failure = await expectLeft(
        CreateContactUseCase(
          contactRepository,
          ledgerRepository,
          activationRepository,
        ).execute(
          ledgerId: ledgerId,
          name: 'عميل جديد',
          avatarColor: '#5C6BC0',
        ),
      );

      expect(failure.code, 'ledger_archived');
      verifyNever(() => contactRepository.create(any()));
    });

    test('UpdateContactUseCase blocks before update', () async {
      final existing = contact();
      when(() => contactRepository.watchByLedger(ledgerId)).thenAnswer(
        (_) => Stream.value([existing]),
      );
      stubArchivedLedgerChain();

      final failure = await expectLeft(
        UpdateContactUseCase(
          contactRepository,
          ledgerRepository,
        ).execute(existing.copyWith(name: 'اسم محدث')),
      );

      expect(failure.code, 'ledger_archived');
      verifyNever(() => contactRepository.update(any()));
    });

    test('DeleteContactUseCase blocks before delete', () async {
      stubArchivedLedgerChain();

      final failure = await expectLeft(
        DeleteContactUseCase(
          contactRepository,
          ledgerRepository,
        ).execute(contactId),
      );

      expect(failure.code, 'ledger_archived');
      verifyNever(() => contactRepository.delete(any()));
    });

    test('UpdateLedgerUseCase blocks before update', () async {
      final existing = userArchivedLedger();
      when(() => ledgerRepository.getById(any())).thenAnswer(
        (_) async => Right(existing),
      );

      final failure = await expectLeft(
        UpdateLedgerUseCase(ledgerRepository).execute(
          existing.copyWith(name: 'اسم جديد'),
        ),
      );

      expect(failure.code, 'ledger_archived');
      verifyNever(() => ledgerRepository.update(any()));
    });

    test('import-archived ledger does not block AddTransactionUseCase', () async {
      when(() => contactRepository.getById(any())).thenAnswer(
        (_) async => Right(contact()),
      );
      when(() => ledgerRepository.getById(any())).thenAnswer(
        (_) async => Right(importArchivedLedger()),
      );
      when(() => transactionRepository.getActiveCount()).thenAnswer(
        (_) async => const Right(0),
      );
      when(() => transactionRepository.create(any())).thenAnswer(
        (_) async => Right(transaction()),
      );
      when(() => checkCreditLimitUseCase.execute(contactId)).thenAnswer(
        (_) async => const Right(CreditWarningLevel.none),
      );

      final result = await AddTransactionUseCase(
        transactionRepository,
        contactRepository,
        ledgerRepository,
        checkCreditLimitUseCase,
        activationRepository,
      ).execute(
        contactId: contactId,
        type: TransactionType.debt,
        amount: 1000,
        currency: 'YER',
      );

      expect(result.isRight(), isTrue);
      verify(() => transactionRepository.create(any())).called(1);
    });
  });
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
