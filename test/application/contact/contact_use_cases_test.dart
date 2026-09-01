import 'dart:async';

import 'package:daftar/application/contact/check_credit_limit_use_case.dart';
import 'package:daftar/application/contact/create_contact_use_case.dart';
import 'package:daftar/application/contact/delete_contact_use_case.dart';
import 'package:daftar/application/contact/get_contacts_use_case.dart';
import 'package:daftar/application/contact/restore_contact_use_case.dart';
import 'package:daftar/application/contact/search_contacts_use_case.dart';
import 'package:daftar/application/contact/update_contact_use_case.dart';
import 'package:daftar/core/constants/app_constants.dart';
import 'package:daftar/core/constants/db_constants.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/entities/contact.dart';
import 'package:daftar/domain/entities/contact_balance.dart';
import 'package:daftar/domain/entities/entitlement.dart';
import 'package:daftar/domain/entities/ledger.dart';
import 'package:daftar/domain/enums/ledger_type.dart';
import 'package:daftar/domain/repositories/activation_repository.dart';
import 'package:daftar/domain/repositories/balance_repository.dart';
import 'package:daftar/domain/repositories/contact_repository.dart';
import 'package:daftar/domain/repositories/ledger_repository.dart';
import 'package:daftar/domain/value_objects/contact_search_hit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockContactRepository extends Mock implements ContactRepository {}

class MockBalanceRepository extends Mock implements BalanceRepository {}

class MockLedgerRepository extends Mock implements LedgerRepository {}

class MockActivationRepository extends Mock implements ActivationRepository {}

void main() {
  late MockContactRepository contactRepository;
  late MockBalanceRepository balanceRepository;
  late MockLedgerRepository ledgerRepository;
  late MockActivationRepository activationRepository;

  setUpAll(() {
    registerFallbackValue(
      const CreateContactParams(
        ledgerId: 'fallback-ledger-id',
        name: 'Fallback Contact',
        avatarColor: '#5C6BC0',
      ),
    );
    registerFallbackValue(
      const UpdateContactParams(
        id: 'fallback-contact-id',
      ),
    );
    registerFallbackValue(
      Contact(
        id: 'fallback-contact-id',
        ledgerId: 'fallback-ledger-id',
        name: 'Fallback Contact',
        avatarColor: '#5C6BC0',
        createdAt: DateTime.utc(2026, 2, 3),
        updatedAt: DateTime.utc(2026, 2, 4),
      ),
    );
    registerFallbackValue(
      ContactBalance(
        contactId: 'fallback-contact-id',
        currencyCode: 'YER',
        totalDebt: 0,
        totalPayment: 0,
        netBalance: 0,
        lastUpdatedAt: DateTime.utc(2026, 2, 4),
      ),
    );
  });

  setUp(() {
    contactRepository = MockContactRepository();
    balanceRepository = MockBalanceRepository();
    ledgerRepository = MockLedgerRepository();
    activationRepository = MockActivationRepository();
    when(() => activationRepository.getEntitlement()).thenAnswer(
      (_) async => Entitlement.defaultFree(),
    );
  });

  CreateContactUseCase buildCreateContactUseCase() => CreateContactUseCase(
    contactRepository,
    ledgerRepository,
    activationRepository,
  );

  group('CreateContactUseCase', () {
    test('returns success and forwards normalized params', () async {
      final useCase = buildCreateContactUseCase();
      const ledgerId = 'ledger-1';
      const avatarColor = '#FF9800';
      final activeLedger = _ledger(id: ledgerId, name: 'دفتر رئيسي');
      final createdContact = Contact(
        id: 'contact-1',
        ledgerId: ledgerId,
        name: 'أحمد',
        phone: '770000000',
        notes: 'ملاحظات',
        creditLimit: 25000,
        creditCurrency: DbConstants.currencyYer,
        avatarColor: avatarColor,
        createdAt: DateTime.utc(2026, 2, 3),
        updatedAt: DateTime.utc(2026, 2, 4),
      );

      when(
        () => ledgerRepository.getById(ledgerId),
      ).thenAnswer((_) async => Right(activeLedger));
      when(
        () => contactRepository.watchByLedger(ledgerId),
      ).thenAnswer((_) => Stream.value(const <Contact>[]));
      when(
        () => contactRepository.getActiveCount(),
      ).thenAnswer((_) async => const Right(0));
      when(
        () => contactRepository.create(any<CreateContactParams>()),
      ).thenAnswer((_) async => Right(createdContact));

      final result = await useCase.execute(
        ledgerId: ledgerId,
        name: '  أحمد  ',
        phone: ' 770000000 ',
        notes: '  ملاحظات  ',
        creditLimit: 25000,
        creditCurrency: ' yer ',
        avatarColor: avatarColor,
      );

      final contact = await expectRight(result);
      expect(contact, createdContact);

      verify(() => ledgerRepository.getById(ledgerId)).called(1);
      verify(() => contactRepository.watchByLedger(ledgerId)).called(1);
      verify(() => contactRepository.getActiveCount()).called(1);
      final captured =
          verify(
                () =>
                    contactRepository.create(captureAny<CreateContactParams>()),
              ).captured.single
              as CreateContactParams;
      expect(captured.ledgerId, ledgerId);
      expect(captured.name, 'أحمد');
      expect(captured.phone, '770000000');
      expect(captured.notes, 'ملاحظات');
      expect(captured.creditLimit, 25000);
      expect(captured.creditCurrency, 'YER');
      expect(captured.avatarColor, avatarColor);
    });

    test('returns validation failure for invalid email', () async {
      final useCase = buildCreateContactUseCase();
      final result = await useCase.execute(
        ledgerId: 'ledger-1',
        name: 'أحمد',
        email: 'not-an-email',
      );
      expect(result.getLeft().toNullable(), isA<ValidationFailure>());
      expect(result.getLeft().toNullable()?.code, 'contact_email_invalid');
      verifyNever(() => contactRepository.create(any<CreateContactParams>()));
    });

    test('forwards plus-alias email', () async {
      final useCase = buildCreateContactUseCase();
      const ledgerId = 'ledger-1';
      final createdContact = Contact(
        id: 'contact-1',
        ledgerId: ledgerId,
        name: 'أحمد',
        email: 'local+tag@gmail.com',
        avatarColor: '#5C6BC0',
        createdAt: DateTime.utc(2026, 2, 3),
        updatedAt: DateTime.utc(2026, 2, 4),
      );
      when(
        () => ledgerRepository.getById(ledgerId),
      ).thenAnswer((_) async => Right(_ledger(id: ledgerId, name: 'دفتر')));
      when(
        () => contactRepository.watchByLedger(ledgerId),
      ).thenAnswer((_) => Stream.value(const <Contact>[]));
      when(
        () => contactRepository.getActiveCount(),
      ).thenAnswer((_) async => const Right(0));
      when(
        () => contactRepository.create(any<CreateContactParams>()),
      ).thenAnswer((_) async => Right(createdContact));

      await useCase.execute(
        ledgerId: ledgerId,
        name: 'أحمد',
        email: ' local+tag@gmail.com ',
      );
      final captured =
          verify(
                () =>
                    contactRepository.create(captureAny<CreateContactParams>()),
              ).captured.single
              as CreateContactParams;
      expect(captured.email, 'local+tag@gmail.com');
    });

    test(
      'returns validation failure for duplicate name in the same ledger',
      () async {
        final useCase = buildCreateContactUseCase();
        const ledgerId = 'ledger-1';
        final activeLedger = _ledger(id: ledgerId, name: 'دفتر رئيسي');
        final existingContact = Contact(
          id: 'contact-existing',
          ledgerId: ledgerId,
          name: 'أحمد',
          avatarColor: '#5C6BC0',
          createdAt: DateTime.utc(2026, 2, 3),
          updatedAt: DateTime.utc(2026, 2, 4),
        );

        when(
          () => ledgerRepository.getById(ledgerId),
        ).thenAnswer((_) async => Right(activeLedger));
        when(
          () => contactRepository.watchByLedger(ledgerId),
        ).thenAnswer((_) => Stream.value([existingContact]));

        final result = await useCase.execute(
          ledgerId: ledgerId,
          name: 'احمد',
          avatarColor: '#5C6BC0',
        );

        final failure = await expectLeft(result);
        expect(failure, isA<ValidationFailure>());
        verify(() => ledgerRepository.getById(ledgerId)).called(1);
        verify(() => contactRepository.watchByLedger(ledgerId)).called(1);
        verifyNever(() => contactRepository.getActiveCount());
        verifyNever(() => contactRepository.create(any<CreateContactParams>()));
      },
    );

    test('returns limit exceeded failure when free limit is reached', () async {
      final useCase = buildCreateContactUseCase();
      const ledgerId = 'ledger-1';
      final activeLedger = _ledger(id: ledgerId, name: 'دفتر رئيسي');

      when(
        () => ledgerRepository.getById(ledgerId),
      ).thenAnswer((_) async => Right(activeLedger));
      when(
        () => contactRepository.watchByLedger(ledgerId),
      ).thenAnswer((_) => Stream.value(const <Contact>[]));
      when(
        () => contactRepository.getActiveCount(),
      ).thenAnswer((_) async => const Right(AppConstants.maxFreeContacts));

      final result = await useCase.execute(
        ledgerId: ledgerId,
        name: 'عميل جديد',
        avatarColor: '#5C6BC0',
      );

      final failure = await expectLeft(result);
      expect(failure, isA<LimitExceededFailure>());
      final limitFailure = failure as LimitExceededFailure;
      expect(limitFailure.featureKey, AppConstants.featureUnlimitedContacts);
      expect(limitFailure.currentCount, AppConstants.maxFreeContacts);
      expect(limitFailure.maxAllowed, AppConstants.maxFreeContacts);
      verify(() => ledgerRepository.getById(ledgerId)).called(1);
      verify(() => contactRepository.watchByLedger(ledgerId)).called(1);
      verify(() => contactRepository.getActiveCount()).called(1);
      verifyNever(() => contactRepository.create(any<CreateContactParams>()));
    });

    test(
      'returns database failure when the parent ledger is missing',
      () async {
        final useCase = buildCreateContactUseCase();
        const ledgerId = 'ledger-1';

        when(() => ledgerRepository.getById(ledgerId)).thenAnswer(
          (_) async => const Left(
            DatabaseFailure(
              'Ledger not found: ledger-1',
              code: 'ledger_not_found',
            ),
          ),
        );

        final result = await useCase.execute(
          ledgerId: ledgerId,
          name: 'عميل جديد',
          avatarColor: '#5C6BC0',
        );

        final failure = await expectLeft(result);
        expect(failure, isA<DatabaseFailure>());

        verify(() => ledgerRepository.getById(ledgerId)).called(1);
        verifyNever(() => contactRepository.watchByLedger(any()));
        verifyNever(() => contactRepository.getActiveCount());
        verifyNever(() => contactRepository.create(any<CreateContactParams>()));
      },
    );

    test(
      'returns database failure when the parent ledger is soft-deleted',
      () async {
        final useCase = buildCreateContactUseCase();
        const ledgerId = 'ledger-1';

        when(() => ledgerRepository.getById(ledgerId)).thenAnswer(
          (_) async => const Left(
            DatabaseFailure(
              'Ledger soft-deleted: ledger-1',
              code: 'ledger_not_found',
            ),
          ),
        );

        final result = await useCase.execute(
          ledgerId: ledgerId,
          name: 'عميل جديد',
          avatarColor: '#5C6BC0',
        );

        final failure = await expectLeft(result);
        expect(failure, isA<DatabaseFailure>());

        verify(() => ledgerRepository.getById(ledgerId)).called(1);
        verifyNever(() => contactRepository.watchByLedger(any()));
        verifyNever(() => contactRepository.getActiveCount());
        verifyNever(() => contactRepository.create(any<CreateContactParams>()));
      },
    );

    test(
      'returns database failure when the active count query fails',
      () async {
        final useCase = buildCreateContactUseCase();
        const ledgerId = 'ledger-1';
        final activeLedger = _ledger(id: ledgerId, name: 'دفتر رئيسي');

        when(
          () => ledgerRepository.getById(ledgerId),
        ).thenAnswer((_) async => Right(activeLedger));
        when(
          () => contactRepository.watchByLedger(ledgerId),
        ).thenAnswer((_) => Stream.value(const <Contact>[]));
        when(() => contactRepository.getActiveCount()).thenAnswer(
          (_) async => const Left(
            DatabaseFailure('count failed', code: 'database_error'),
          ),
        );

        final result = await useCase.execute(
          ledgerId: ledgerId,
          name: 'عميل جديد',
          avatarColor: '#5C6BC0',
        );

        final failure = await expectLeft(result);
        expect(failure, isA<DatabaseFailure>());

        verify(() => ledgerRepository.getById(ledgerId)).called(1);
        verify(() => contactRepository.watchByLedger(ledgerId)).called(1);
        verify(() => contactRepository.getActiveCount()).called(1);
        verifyNever(() => contactRepository.create(any<CreateContactParams>()));
      },
    );
  });

  group('GetContactsUseCase', () {
    test('sorts contacts by name in Dart', () async {
      final useCase = GetContactsUseCase(contactRepository);
      const ledgerId = 'ledger-1';
      final contactB = _contact(
        id: 'b',
        ledgerId: ledgerId,
        name: 'زيد',
        updatedAt: DateTime.utc(2026, 2, 4),
      );
      final contactA = _contact(
        id: 'a',
        ledgerId: ledgerId,
        name: 'أحمد',
        updatedAt: DateTime.utc(2026, 2, 3),
      );

      when(
        () => contactRepository.watchByLedger(ledgerId),
      ).thenAnswer((_) => Stream.value([contactB, contactA]));

      await expectLater(
        useCase.execute(ledgerId, sortBy: 'name'),
        emits([contactA, contactB]),
      );
    });

    test('sorts contacts by recent updates in Dart', () async {
      final useCase = GetContactsUseCase(contactRepository);
      const ledgerId = 'ledger-1';
      final contactOld = _contact(
        id: 'old',
        ledgerId: ledgerId,
        name: 'أحمد',
        updatedAt: DateTime.utc(2026, 2, 3),
      );
      final contactNew = _contact(
        id: 'new',
        ledgerId: ledgerId,
        name: 'زيد',
        updatedAt: DateTime.utc(2026, 2, 4),
      );

      when(
        () => contactRepository.watchByLedger(ledgerId),
      ).thenAnswer((_) => Stream.value([contactOld, contactNew]));

      await expectLater(
        useCase.execute(ledgerId),
        emits([contactNew, contactOld]),
      );
    });
  });

  group('SearchContactsUseCase', () {
    test('returns search results from the repository', () async {
      final useCase = SearchContactsUseCase(contactRepository);
      final contact = _contact(
        id: '1',
        ledgerId: 'ledger-1',
        name: 'أحمد',
        updatedAt: DateTime.utc(2026, 2, 3),
      );
      final results = [
        ContactSearchHit(
          contact: contact,
          ledgerName: 'Main',
          isLedgerUserArchived: false,
        ),
      ];

      when(
        () => contactRepository.search('أحمد'),
      ).thenAnswer((_) async => Right(results));

      final result = await useCase.execute('أحمد');

      final hits = await expectRight(result);
      expect(hits, results);
      verify(() => contactRepository.search('أحمد')).called(1);
    });
  });

  group('UpdateContactUseCase', () {
    test('updates the contact successfully', () async {
      final useCase = UpdateContactUseCase(
        contactRepository,
        ledgerRepository,
      );
      final inputContact = _contact(
        id: 'contact-1',
        ledgerId: 'ledger-1',
        name: '  عميل محدث  ',
        phone: ' 770000111 ',
        notes: '  ملاحظات جديدة  ',
        creditLimit: 30000,
        creditCurrency: ' yer ',
        avatarColor: '#FF9800',
        updatedAt: DateTime.utc(2026, 2, 3),
      );
      final updatedContact = inputContact.copyWith(
        name: 'عميل محدث',
        phone: '770000111',
        notes: 'ملاحظات جديدة',
        creditCurrency: DbConstants.currencyYer,
        updatedAt: DateTime.utc(2026, 2, 5),
        syncVersion: inputContact.syncVersion + 1,
      );

      when(
        () => ledgerRepository.getById(inputContact.ledgerId),
      ).thenAnswer(
        (_) async => Right(_ledger(id: inputContact.ledgerId, name: 'دفتر')),
      );
      when(
        () => contactRepository.watchByLedger(inputContact.ledgerId),
      ).thenAnswer((_) => Stream.value([inputContact]));
      when(
        () => contactRepository.update(any<UpdateContactParams>()),
      ).thenAnswer((_) async => Right(updatedContact));

      final result = await useCase.execute(inputContact);

      final contact = await expectRight(result);
      expect(contact, updatedContact);

      final captured =
          verify(
                () =>
                    contactRepository.update(captureAny<UpdateContactParams>()),
              ).captured.single
              as UpdateContactParams;
      expect(captured.id, inputContact.id);
      expect(captured.name, 'عميل محدث');
      expect(captured.phone, '770000111');
      expect(captured.notes, 'ملاحظات جديدة');
      expect(captured.creditLimit, 30000);
      expect(captured.creditCurrency, 'YER');
    });
  });

  group('DeleteContactUseCase', () {
    test('soft-deletes the contact after loading it', () async {
      final useCase = DeleteContactUseCase(
        contactRepository,
        ledgerRepository,
      );
      final existingContact = _contact(
        id: 'contact-1',
        ledgerId: 'ledger-1',
        name: 'أحمد',
        updatedAt: DateTime.utc(2026, 2, 3),
      );

      when(
        () => contactRepository.getById(existingContact.id),
      ).thenAnswer((_) async => Right(existingContact));
      when(
        () => ledgerRepository.getById(existingContact.ledgerId),
      ).thenAnswer(
        (_) async => Right(
          _ledger(id: existingContact.ledgerId, name: 'دفتر'),
        ),
      );
      when(
        () => contactRepository.delete(existingContact.id),
      ).thenAnswer((_) async => const Right(unit));

      final result = await useCase.execute(existingContact.id);

      final contact = await expectRight(result);
      expect(contact.id, existingContact.id);
      expect(contact.isDeleted, isTrue);
      expect(contact.syncVersion, existingContact.syncVersion + 1);

      verify(() => contactRepository.getById(existingContact.id)).called(1);
      verify(() => contactRepository.delete(existingContact.id)).called(1);
    });
  });

  group('RestoreContactUseCase', () {
    test('restores the contact with a trimmed identifier', () async {
      final useCase = RestoreContactUseCase(contactRepository);
      final restoredContact = _contact(
        id: 'contact-1',
        ledgerId: 'ledger-1',
        name: 'أحمد',
        updatedAt: DateTime.utc(2026, 2, 5),
      );

      when(
        () => contactRepository.restore('contact-1'),
      ).thenAnswer((_) async => Right(restoredContact));

      final result = await useCase.execute('  contact-1  ');

      final contact = await expectRight(result);
      expect(contact, restoredContact);

      verify(() => contactRepository.restore('contact-1')).called(1);
    });

    test('returns validation failure for empty id', () async {
      final useCase = RestoreContactUseCase(contactRepository);

      final result = await useCase.execute('   ');

      final failure = await expectLeft(result);
      expect(failure, isA<ValidationFailure>());
      verifyNever(() => contactRepository.restore(any()));
    });

    test('maps repository failure as-is', () async {
      final useCase = RestoreContactUseCase(contactRepository);

      when(() => contactRepository.restore('contact-1')).thenAnswer(
        (_) async => const Left(
          DatabaseFailure('restore failed', code: 'database_error'),
        ),
      );

      final result = await useCase.execute('contact-1');

      final failure = await expectLeft(result);
      expect(failure, isA<DatabaseFailure>());
      verify(() => contactRepository.restore('contact-1')).called(1);
    });
  });

  group('CheckCreditLimitUseCase', () {
    test('returns none when no credit limit is configured', () async {
      final useCase = CheckCreditLimitUseCase(
        contactRepository,
        balanceRepository,
      );
      final contact = _contact(
        id: 'contact-1',
        ledgerId: 'ledger-1',
        name: 'أحمد',
        updatedAt: DateTime.utc(2026, 2, 3),
      );

      when(
        () => contactRepository.getById(contact.id),
      ).thenAnswer((_) async => Right(contact));

      final result = await useCase.execute(contact.id);

      final warning = await expectRight(result);
      expect(warning, CreditWarningLevel.none);
      verify(() => contactRepository.getById(contact.id)).called(1);
      verifyNever(() => balanceRepository.getByContact(any<String>()));
    });

    test('returns near limit when balance reaches 80 percent', () async {
      final useCase = CheckCreditLimitUseCase(
        contactRepository,
        balanceRepository,
      );
      final contact = _contact(
        id: 'contact-1',
        ledgerId: 'ledger-1',
        name: 'أحمد',
        creditLimit: 1000,
        creditCurrency: DbConstants.currencyYer,
        updatedAt: DateTime.utc(2026, 2, 3),
      );
      final balances = [
        _balance(
          contactId: contact.id,
          currencyCode: DbConstants.currencyYer,
          debtAmount: 800,
        ),
      ];

      when(
        () => contactRepository.getById(contact.id),
      ).thenAnswer((_) async => Right(contact));
      when(
        () => balanceRepository.getByContact(contact.id),
      ).thenAnswer((_) async => Right(balances));

      final result = await useCase.execute(contact.id);

      final level = await expectRight(result);
      expect(level, CreditWarningLevel.warning);
    });

    test('returns breached when balance exceeds the limit', () async {
      final useCase = CheckCreditLimitUseCase(
        contactRepository,
        balanceRepository,
      );
      final contact = _contact(
        id: 'contact-1',
        ledgerId: 'ledger-1',
        name: 'أحمد',
        creditLimit: 1000,
        creditCurrency: DbConstants.currencyYer,
        updatedAt: DateTime.utc(2026, 2, 3),
      );
      final balances = [
        _balance(
          contactId: contact.id,
          currencyCode: DbConstants.currencyYer,
          debtAmount: 1200,
        ),
      ];

      when(
        () => contactRepository.getById(contact.id),
      ).thenAnswer((_) async => Right(contact));
      when(
        () => balanceRepository.getByContact(contact.id),
      ).thenAnswer((_) async => Right(balances));

      final result = await useCase.execute(contact.id);

      final level = await expectRight(result);
      expect(level, CreditWarningLevel.exceeded);
    });

    test('returns contact repository failure', () async {
      final useCase = CheckCreditLimitUseCase(
        contactRepository,
        balanceRepository,
      );
      when(() => contactRepository.getById('contact-1')).thenAnswer(
        (_) async => const Left(DatabaseFailure('missing')),
      );

      final result = await useCase.execute('contact-1');

      final failure = await expectLeft(result);
      expect(failure, isA<DatabaseFailure>());
    });

    test('returns balance repository failure', () async {
      final useCase = CheckCreditLimitUseCase(
        contactRepository,
        balanceRepository,
      );
      final contact = _contact(
        id: 'contact-1',
        ledgerId: 'ledger-1',
        name: 'أحمد',
        creditLimit: 1000,
        creditCurrency: DbConstants.currencyYer,
        updatedAt: DateTime.utc(2026, 2, 3),
      );
      when(() => contactRepository.getById(contact.id)).thenAnswer(
        (_) async => Right(contact),
      );
      when(() => balanceRepository.getByContact(contact.id)).thenAnswer(
        (_) async => const Left(DatabaseFailure('balance failed')),
      );

      final result = await useCase.execute(contact.id);

      final failure = await expectLeft(result);
      expect(failure, isA<DatabaseFailure>());
    });

    test('returns none when configured currency balance is missing', () async {
      final useCase = CheckCreditLimitUseCase(
        contactRepository,
        balanceRepository,
      );
      final contact = _contact(
        id: 'contact-1',
        ledgerId: 'ledger-1',
        name: 'أحمد',
        creditLimit: 1000,
        creditCurrency: 'USD',
        updatedAt: DateTime.utc(2026, 2, 3),
      );
      when(() => contactRepository.getById(contact.id)).thenAnswer(
        (_) async => Right(contact),
      );
      when(() => balanceRepository.getByContact(contact.id)).thenAnswer(
        (_) async => Right([
          _balance(
            contactId: contact.id,
            currencyCode: DbConstants.currencyYer,
            debtAmount: 900,
          ),
        ]),
      );

      final result = await useCase.execute(contact.id);

      final level = await expectRight(result);
      expect(level, CreditWarningLevel.none);
    });

    test('uses lowest balance when credit currency is unset', () async {
      final useCase = CheckCreditLimitUseCase(
        contactRepository,
        balanceRepository,
      );
      final contact = _contact(
        id: 'contact-1',
        ledgerId: 'ledger-1',
        name: 'أحمد',
        creditLimit: 1000,
        updatedAt: DateTime.utc(2026, 2, 3),
      );
      when(() => contactRepository.getById(contact.id)).thenAnswer(
        (_) async => Right(contact),
      );
      when(() => balanceRepository.getByContact(contact.id)).thenAnswer(
        (_) async => Right([
          _balance(
            contactId: contact.id,
            currencyCode: DbConstants.currencyYer,
            debtAmount: 500,
          ),
          _balance(
            contactId: contact.id,
            currencyCode: 'USD',
            debtAmount: 1200,
          ),
        ]),
      );

      final result = await useCase.execute(contact.id);

      final level = await expectRight(result);
      expect(level, CreditWarningLevel.exceeded);
    });
  });
}

Contact _contact({
  required String id,
  required String ledgerId,
  required String name,
  required DateTime updatedAt,
  String? phone,
  String? notes,
  int? creditLimit,
  String? creditCurrency,
  String avatarColor = '#5C6BC0',
}) {
  return Contact(
    id: id,
    ledgerId: ledgerId,
    name: name,
    phone: phone,
    notes: notes,
    creditLimit: creditLimit,
    creditCurrency: creditCurrency,
    avatarColor: avatarColor,
    createdAt: DateTime.utc(2026, 2, 3),
    updatedAt: updatedAt,
  );
}

ContactBalance _balance({
  required String contactId,
  required String currencyCode,
  required int debtAmount,
}) {
  return ContactBalance(
    contactId: contactId,
    currencyCode: currencyCode,
    totalDebt: debtAmount,
    totalPayment: 0,
    netBalance: -debtAmount,
    lastUpdatedAt: DateTime.utc(2026, 2, 4),
  );
}

Ledger _ledger({
  required String id,
  required String name,
}) {
  return Ledger(
    id: id,
    name: name,
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
