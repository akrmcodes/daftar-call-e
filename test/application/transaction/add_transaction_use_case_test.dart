import 'dart:async';

import 'package:daftar/application/contact/check_credit_limit_use_case.dart';
import 'package:daftar/application/transaction/add_transaction_use_case.dart';
import 'package:daftar/core/constants/app_constants.dart';
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
import 'package:daftar/domain/repositories/transaction_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockTransactionRepository extends Mock implements TransactionRepository {}

class MockContactRepository extends Mock implements ContactRepository {}

class MockCheckCreditLimitUseCase extends Mock
    implements CheckCreditLimitUseCase {}

class MockActivationRepository extends Mock implements ActivationRepository {}

class MockLedgerRepository extends Mock implements LedgerRepository {}

void main() {
  late MockTransactionRepository transactionRepository;
  late MockContactRepository contactRepository;
  late MockLedgerRepository ledgerRepository;
  late MockCheckCreditLimitUseCase checkCreditLimitUseCase;
  late MockActivationRepository activationRepository;

  setUpAll(() {
    registerFallbackValue(
      CreateTransactionParams(
        contactId: 'fallback-contact-id',
        type: TransactionType.debt,
        amount: 1,
        currency: 'YER',
        transactionDate: DateTime.utc(2026, 2, 3),
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

  AddTransactionUseCase buildUseCase() => AddTransactionUseCase(
    transactionRepository,
    contactRepository,
    ledgerRepository,
    checkCreditLimitUseCase,
    activationRepository,
  );

  void stubLiveLedger(String ledgerId) {
    when(
      () => ledgerRepository.getById(ledgerId),
    ).thenAnswer((_) async => Right(_ledger(id: ledgerId)));
  }

  group('AddTransactionUseCase', () {
    test('returns success with no credit warning', () async {
      final useCase = buildUseCase();

      const contactId = 'contact-1';
      final createdAt = DateTime.utc(2026, 2, 6);
      final activeContact = _contact(id: contactId, ledgerId: 'ledger-1');
      final createdTransaction = _transaction(
        id: 'txn-1',
        contactId: contactId,
        type: TransactionType.debt,
        amount: 7900,
        currency: 'YER',
        description: 'مراجعة الفاتورة',
        itemName: 'سكر',
        attachmentPath: '/tmp/receipt.pdf',
        transactionDate: createdAt,
      );

      when(
        () => contactRepository.getById(contactId),
      ).thenAnswer((_) async => Right(activeContact));
      stubLiveLedger('ledger-1');
      when(
        () => transactionRepository.getActiveCount(),
      ).thenAnswer((_) async => const Right(0));
      when(
        () => transactionRepository.create(any<CreateTransactionParams>()),
      ).thenAnswer((_) async => Right(createdTransaction));
      when(
        () => checkCreditLimitUseCase.execute(contactId),
      ).thenAnswer((_) async => const Right(CreditWarningLevel.none));

      final result = await useCase.execute(
        contactId: '  $contactId  ',
        type: TransactionType.debt,
        amount: 7900,
        currency: ' yer ',
        description: '  مراجعة الفاتورة  ',
        itemName: '  سكر  ',
        attachmentPath: '  /tmp/receipt.pdf  ',
        transactionDate: createdAt,
      );

      final value = await expectRight(result);
      expect(value.transaction, createdTransaction);
      expect(value.warningLevel, CreditWarningLevel.none);

      final captured =
          verify(
                () => transactionRepository.create(
                  captureAny<CreateTransactionParams>(),
                ),
              ).captured.single
              as CreateTransactionParams;
      expect(captured.contactId, contactId);
      expect(captured.type, TransactionType.debt);
      expect(captured.amount, 7900);
      expect(captured.currency, 'YER');
      expect(captured.description, 'مراجعة الفاتورة');
      expect(captured.itemName, 'سكر');
      expect(captured.attachmentPath, '/tmp/receipt.pdf');
      expect(captured.transactionDate, createdAt);

      verify(() => contactRepository.getById(contactId)).called(1);
      verify(() => transactionRepository.getActiveCount()).called(1);
      verify(() => checkCreditLimitUseCase.execute(contactId)).called(1);
    });

    test('propagates warning level from checker', () async {
      final useCase = buildUseCase();

      const contactId = 'contact-1';
      final createdAt = DateTime.utc(2026, 2, 6);
      final activeContact = _contact(id: contactId, ledgerId: 'ledger-1');
      final createdTransaction = _transaction(
        id: 'txn-2',
        contactId: contactId,
        type: TransactionType.debt,
        amount: 8000,
        currency: 'YER',
        transactionDate: createdAt,
      );

      when(
        () => contactRepository.getById(contactId),
      ).thenAnswer((_) async => Right(activeContact));
      stubLiveLedger('ledger-1');
      when(
        () => transactionRepository.getActiveCount(),
      ).thenAnswer((_) async => const Right(0));
      when(
        () => transactionRepository.create(any<CreateTransactionParams>()),
      ).thenAnswer((_) async => Right(createdTransaction));
      when(
        () => checkCreditLimitUseCase.execute(contactId),
      ).thenAnswer((_) async => const Right(CreditWarningLevel.warning));

      final result = await useCase.execute(
        contactId: contactId,
        type: TransactionType.debt,
        amount: 8000,
        currency: 'YER',
        transactionDate: createdAt,
      );

      final value = await expectRight(result);
      expect(value.transaction, createdTransaction);
      expect(value.warningLevel, CreditWarningLevel.warning);
      verify(() => contactRepository.getById(contactId)).called(1);
      verify(() => checkCreditLimitUseCase.execute(contactId)).called(1);
    });

    test('propagates exceeded level from checker', () async {
      final useCase = buildUseCase();

      const contactId = 'contact-1';
      final createdAt = DateTime.utc(2026, 2, 6);
      final activeContact = _contact(id: contactId, ledgerId: 'ledger-1');
      final createdTransaction = _transaction(
        id: 'txn-3',
        contactId: contactId,
        type: TransactionType.debt,
        amount: 10100,
        currency: 'YER',
        transactionDate: createdAt,
      );

      when(
        () => contactRepository.getById(contactId),
      ).thenAnswer((_) async => Right(activeContact));
      stubLiveLedger('ledger-1');
      when(
        () => transactionRepository.getActiveCount(),
      ).thenAnswer((_) async => const Right(0));
      when(
        () => transactionRepository.create(any<CreateTransactionParams>()),
      ).thenAnswer((_) async => Right(createdTransaction));
      when(
        () => checkCreditLimitUseCase.execute(contactId),
      ).thenAnswer((_) async => const Right(CreditWarningLevel.exceeded));

      final result = await useCase.execute(
        contactId: contactId,
        type: TransactionType.debt,
        amount: 10100,
        currency: 'YER',
        transactionDate: createdAt,
      );

      final value = await expectRight(result);
      expect(value.transaction, createdTransaction);
      expect(value.warningLevel, CreditWarningLevel.exceeded);
      verify(() => contactRepository.getById(contactId)).called(1);
      verify(() => checkCreditLimitUseCase.execute(contactId)).called(1);
    });

    test('returns free tier failure at the transaction cap', () async {
      final useCase = buildUseCase();
      const contactId = 'contact-1';
      final activeContact = _contact(id: contactId, ledgerId: 'ledger-1');

      when(
        () => contactRepository.getById(contactId),
      ).thenAnswer((_) async => Right(activeContact));
      stubLiveLedger('ledger-1');
      when(
        () => transactionRepository.getActiveCount(),
      ).thenAnswer((_) async => const Right(AppConstants.maxFreeTransactions));

      final result = await useCase.execute(
        contactId: contactId,
        type: TransactionType.debt,
        amount: 500,
        currency: 'YER',
      );

      final failure = await expectLeft(result);
      expect(failure, isA<LimitExceededFailure>());
      final limitFailure = failure as LimitExceededFailure;
      expect(
        limitFailure.featureKey,
        AppConstants.featureUnlimitedTransactions,
      );
      expect(limitFailure.currentCount, AppConstants.maxFreeTransactions);
      expect(limitFailure.maxAllowed, AppConstants.maxFreeTransactions);

      verify(() => contactRepository.getById(contactId)).called(1);
      verify(() => transactionRepository.getActiveCount()).called(1);
      verifyNever(
        () => transactionRepository.create(any<CreateTransactionParams>()),
      );
      verifyNever(() => checkCreditLimitUseCase.execute(any()));
    });

    test('returns database failure when parent contact is missing', () async {
      final useCase = buildUseCase();
      const contactId = 'contact-1';

      when(
        () => contactRepository.getById(contactId),
      ).thenAnswer(
        (_) async => const Left(
          DatabaseFailure('Contact not found: contact-1', code: 'contact_not_found'),
        ),
      );

      final result = await useCase.execute(
        contactId: contactId,
        type: TransactionType.debt,
        amount: 500,
        currency: 'YER',
      );

      final failure = await expectLeft(result);
      expect(failure, isA<DatabaseFailure>());

      verify(() => contactRepository.getById(contactId)).called(1);
      verifyNever(() => transactionRepository.getActiveCount());
      verifyNever(
        () => transactionRepository.create(any<CreateTransactionParams>()),
      );
      verifyNever(() => checkCreditLimitUseCase.execute(any()));
    });

    test(
      'returns database failure when parent contact is soft-deleted',
      () async {
        final useCase = buildUseCase();
        const contactId = 'contact-1';

        when(
          () => contactRepository.getById(contactId),
        ).thenAnswer(
          (_) async => const Left(
            DatabaseFailure(
              'Contact soft-deleted: contact-1',
              code: 'contact_not_found',
            ),
          ),
        );

        final result = await useCase.execute(
          contactId: contactId,
          type: TransactionType.debt,
          amount: 500,
          currency: 'YER',
        );

        final failure = await expectLeft(result);
        expect(failure, isA<DatabaseFailure>());

        verify(() => contactRepository.getById(contactId)).called(1);
        verifyNever(() => transactionRepository.getActiveCount());
        verifyNever(
          () => transactionRepository.create(any<CreateTransactionParams>()),
        );
        verifyNever(() => checkCreditLimitUseCase.execute(any()));
      },
    );

    test('returns database failure when the count query fails', () async {
      final useCase = buildUseCase();
      const contactId = 'contact-1';
      final activeContact = _contact(id: contactId, ledgerId: 'ledger-1');

      when(
        () => contactRepository.getById(contactId),
      ).thenAnswer((_) async => Right(activeContact));
      stubLiveLedger('ledger-1');
      when(
        () => transactionRepository.getActiveCount(),
      ).thenAnswer(
        (_) async => const Left(
          DatabaseFailure('count failed', code: 'database_error'),
        ),
      );

      final result = await useCase.execute(
        contactId: contactId,
        type: TransactionType.debt,
        amount: 1000,
        currency: 'YER',
      );

      final failure = await expectLeft(result);
      expect(failure, isA<DatabaseFailure>());

      verify(() => contactRepository.getById(contactId)).called(1);
      verify(() => transactionRepository.getActiveCount()).called(1);
      verifyNever(
        () => transactionRepository.create(any<CreateTransactionParams>()),
      );
      verifyNever(() => checkCreditLimitUseCase.execute(any()));
    });

    test('returns repository failure without post-operation checks', () async {
      final useCase = buildUseCase();
      const contactId = 'contact-1';
      final activeContact = _contact(id: contactId, ledgerId: 'ledger-1');

      when(
        () => contactRepository.getById(contactId),
      ).thenAnswer((_) async => Right(activeContact));
      stubLiveLedger('ledger-1');
      when(
        () => transactionRepository.getActiveCount(),
      ).thenAnswer((_) async => const Right(0));
      when(
        () => transactionRepository.create(any<CreateTransactionParams>()),
      ).thenAnswer(
        (_) async => const Left(
          DatabaseFailure('create failed', code: 'database_error'),
        ),
      );

      final result = await useCase.execute(
        contactId: contactId,
        type: TransactionType.debt,
        amount: 1000,
        currency: 'YER',
      );

      final failure = await expectLeft(result);
      expect(failure, isA<DatabaseFailure>());

      verify(() => contactRepository.getById(contactId)).called(1);
      verify(() => transactionRepository.getActiveCount()).called(1);
      verify(
        () => transactionRepository.create(any<CreateTransactionParams>()),
      ).called(1);
      verifyNever(() => checkCreditLimitUseCase.execute(any()));
    });

    test(
      'returns validation failure for zero amount without side effects',
      () async {
        final useCase = buildUseCase();

        final result = await useCase.execute(
          contactId: 'contact-1',
          type: TransactionType.debt,
          amount: 0,
          currency: 'YER',
        );

        final failure = await expectLeft(result);
        expect(failure, isA<InvalidAmountFailure>());

        verifyNever(() => contactRepository.getById(any()));
        verifyNever(() => transactionRepository.getActiveCount());
        verifyNever(
          () => transactionRepository.create(any<CreateTransactionParams>()),
        );
        verifyNever(() => checkCreditLimitUseCase.execute(any()));
      },
    );
  });
}

Transaction _transaction({
  required String id,
  required String contactId,
  required TransactionType type,
  required int amount,
  required String currency,
  required DateTime transactionDate,
  String? description,
  String? itemName,
  String? attachmentPath,
}) {
  return Transaction(
    id: id,
    contactId: contactId,
    type: type,
    amount: amount,
    currency: currency,
    transactionDate: transactionDate,
    description: description,
    itemName: itemName,
    attachmentPath: attachmentPath,
    createdAt: transactionDate,
    updatedAt: transactionDate,
  );
}

Contact _contact({
  required String id,
  required String ledgerId,
}) {
  return Contact(
    id: id,
    ledgerId: ledgerId,
    name: 'عميل',
    avatarColor: '#5C6BC0',
    createdAt: DateTime.utc(2026, 2, 3),
    updatedAt: DateTime.utc(2026, 2, 4),
  );
}

Ledger _ledger({required String id}) {
  return Ledger(
    id: id,
    name: 'دفتر',
    type: LedgerType.custom,
    icon: 'folder',
    color: '#5C6BC0',
    sortOrder: 0,
    createdAt: DateTime.utc(2026, 2, 3),
    updatedAt: DateTime.utc(2026, 2, 4),
  );
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
