import 'package:daftar/application/ledger/archive_ledger_use_case.dart';
import 'package:daftar/core/constants/app_constants.dart';
import 'package:daftar/core/constants/db_constants.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/entities/entitlement.dart';
import 'package:daftar/domain/entities/ledger.dart';
import 'package:daftar/domain/enums/feature_flag.dart';
import 'package:daftar/domain/enums/ledger_type.dart';
import 'package:daftar/domain/enums/transaction_type.dart';
import 'package:daftar/domain/repositories/activation_repository.dart';
import 'package:daftar/domain/repositories/contact_repository.dart';
import 'package:daftar/domain/repositories/ledger_repository.dart';
import 'package:daftar/domain/repositories/transaction_repository.dart';
import 'package:daftar/domain/value_objects/carry_forward_preview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/ledger_archiving_test_harness.dart';

class MockLedgerRepository extends Mock implements LedgerRepository {}

class MockContactRepository extends Mock implements ContactRepository {}

class MockTransactionRepository extends Mock implements TransactionRepository {}

class MockActivationRepository extends Mock implements ActivationRepository {}

void main() {
  group('Carry forward repository mapping', () {
    late LedgerArchivingTestHarness harness;

    setUp(() {
      harness = LedgerArchivingTestHarness();
    });

    tearDown(() async {
      await harness.close();
    });

    Future<void> runCarryForward({
      required String sourceId,
      required String targetId,
      String operationId = 'carry-forward-op',
    }) async {
      await expectRight(
        harness.ledgerRepository.archiveWithCarryForward(
          ArchiveWithCarryForwardParams(
            sourceLedgerId: sourceId,
            targetLedgerId: targetId,
            operationId: operationId,
            openingBalanceItemName: 'رصيد افتتاحي',
            openingBalanceDescription: 'ترحيل',
          ),
        ),
      );
    }

    test('maps negative net balance to debt transaction', () async {
      final source = await harness.seedLedger(name: 'المصدر');
      final target = await harness.seedLedger(name: 'الهدف');
      final contact = await harness.seedContact(
        ledgerId: source.id,
        name: 'مدين',
      );
      await harness.seedDebt(contactId: contact.id, amount: 1500);

      await runCarryForward(sourceId: source.id, targetId: target.id);

      final targetContacts =
          await harness.contactRepository.watchByLedger(target.id).first;
      final transactions = await expectRight(
        harness.transactionRepository.getByContact(targetContacts.single.id),
      );
      expect(transactions, hasLength(1));
      expect(transactions.single.type, TransactionType.debt);
      expect(transactions.single.amount, 1500);
    });

    test('maps positive net balance to payment transaction', () async {
      final source = await harness.seedLedger(name: 'المصدر');
      final target = await harness.seedLedger(name: 'الهدف');
      final contact = await harness.seedContact(
        ledgerId: source.id,
        name: 'دائن',
      );
      await harness.seedPayment(contactId: contact.id, amount: 800);

      await runCarryForward(sourceId: source.id, targetId: target.id);

      final targetContacts =
          await harness.contactRepository.watchByLedger(target.id).first;
      final transactions = await expectRight(
        harness.transactionRepository.getByContact(targetContacts.single.id),
      );
      expect(transactions, hasLength(1));
      expect(transactions.single.type, TransactionType.payment);
      expect(transactions.single.amount, 800);
    });

    test('skips contacts with exactly zero net balance', () async {
      final source = await harness.seedLedger(name: 'المصدر');
      final target = await harness.seedLedger(name: 'الهدف');
      final debtor = await harness.seedContact(
        ledgerId: source.id,
        name: 'مدين',
      );
      await harness.seedContact(ledgerId: source.id, name: 'متوازن');
      await harness.seedDebt(contactId: debtor.id, amount: 500);

      final result = await expectRight(
        harness.ledgerRepository.archiveWithCarryForward(
          ArchiveWithCarryForwardParams(
            sourceLedgerId: source.id,
            targetLedgerId: target.id,
            operationId: 'carry-forward-zero-skip',
            openingBalanceItemName: 'رصيد افتتاحي',
            openingBalanceDescription: 'ترحيل',
          ),
        ),
      );

      expect(result.transactionsCreated, 1);
      expect(result.contactsCreated, 1);

      final targetContacts =
          await harness.contactRepository.watchByLedger(target.id).first;
      expect(targetContacts, hasLength(1));
      expect(targetContacts.single.name, 'مدين');
    });

    test('creates one transaction per non-zero currency on a contact', () async {
      final source = await harness.seedLedger(name: 'المصدر');
      final target = await harness.seedLedger(name: 'الهدف');
      final contact = await harness.seedContact(
        ledgerId: source.id,
        name: 'متعدد العملات',
      );
      await harness.seedDebt(
        contactId: contact.id,
        amount: 1000,
        currency: DbConstants.currencyUsd,
      );
      await harness.seedPayment(
        contactId: contact.id,
        amount: 300,
        currency: DbConstants.currencySar,
      );

      final result = await expectRight(
        harness.ledgerRepository.archiveWithCarryForward(
          ArchiveWithCarryForwardParams(
            sourceLedgerId: source.id,
            targetLedgerId: target.id,
            operationId: 'carry-forward-multi-currency',
            openingBalanceItemName: 'رصيد افتتاحي',
            openingBalanceDescription: 'ترحيل',
          ),
        ),
      );

      expect(result.transactionsCreated, 2);

      final targetContacts =
          await harness.contactRepository.watchByLedger(target.id).first;
      final transactions = await expectRight(
        harness.transactionRepository.getByContact(targetContacts.single.id),
      );
      expect(transactions, hasLength(2));
      expect(
        transactions.map((row) => row.currency).toSet(),
        {DbConstants.currencyUsd, DbConstants.currencySar},
      );
    });
  });

  group('Carry forward repository preflight', () {
    late LedgerArchivingTestHarness harness;

    setUp(() {
      harness = LedgerArchivingTestHarness();
    });

    tearDown(() async {
      await harness.close();
    });

    test('rejects same-ledger target', () async {
      final source = await harness.seedLedger(name: 'المصدر');

      final failure = await expectLeft(
        harness.ledgerRepository.archiveWithCarryForward(
          ArchiveWithCarryForwardParams(
            sourceLedgerId: source.id,
            targetLedgerId: source.id,
            operationId: 'same-ledger',
            openingBalanceItemName: 'رصيد افتتاحي',
            openingBalanceDescription: 'ترحيل',
          ),
        ),
      );

      expect(failure, isA<ValidationFailure>());
      expect(failure.code, 'carry_forward_same_ledger');
    });

    test('rejects user-archived target ledger', () async {
      final source = await harness.seedLedger(name: 'المصدر');
      final target = await harness.seedLedger(name: 'الهدف');
      final contact = await harness.seedContact(
        ledgerId: source.id,
        name: 'مدين',
      );
      await harness.seedDebt(contactId: contact.id, amount: 100);
      await harness.setLedgerFlags(target.id, isUserArchived: true);

      final failure = await expectLeft(
        harness.ledgerRepository.archiveWithCarryForward(
          ArchiveWithCarryForwardParams(
            sourceLedgerId: source.id,
            targetLedgerId: target.id,
            operationId: 'archived-target',
            openingBalanceItemName: 'رصيد افتتاحي',
            openingBalanceDescription: 'ترحيل',
          ),
        ),
      );

      expect(failure, isA<ValidationFailure>());
      expect(failure.code, 'carry_forward_invalid_target');
    });
  });

  group('Carry forward use case preflight', () {
    late MockLedgerRepository ledgerRepository;
    late MockContactRepository contactRepository;
    late MockTransactionRepository transactionRepository;
    late MockActivationRepository activationRepository;

    setUpAll(() {
      registerFallbackValue(
        const ArchiveWithCarryForwardParams(
          sourceLedgerId: 'fallback-source',
          targetLedgerId: 'fallback-target',
          operationId: 'fallback-op',
          openingBalanceItemName: 'fallback-item',
          openingBalanceDescription: 'fallback-desc',
        ),
      );
      registerFallbackValue(
        Ledger(
          id: 'fallback-ledger',
          name: 'Fallback',
          type: LedgerType.custom,
          icon: 'folder',
          color: '#000000',
          sortOrder: 0,
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026, 1, 2),
        ),
      );
    });

    setUp(() {
      ledgerRepository = MockLedgerRepository();
      contactRepository = MockContactRepository();
      transactionRepository = MockTransactionRepository();
      activationRepository = MockActivationRepository();
      when(() => activationRepository.getEntitlement()).thenAnswer(
        (_) async => Entitlement.defaultFree(),
      );
    });

    ArchiveLedgerUseCase buildUseCase() => ArchiveLedgerUseCase(
      ledgerRepository,
      contactRepository,
      transactionRepository,
      activationRepository,
    );

    Ledger liveLedger(String id, {bool isUserArchived = false}) => Ledger(
      id: id,
      name: 'Live',
      type: LedgerType.custom,
      icon: 'folder',
      color: '#424242',
      sortOrder: 0,
      createdAt: DateTime.utc(2026, 3),
      updatedAt: DateTime.utc(2026, 3, 2),
      isUserArchived: isUserArchived,
    );

    test('blocks tier-locked archive with carry-forward', () async {
      when(
        () => activationRepository.isFeatureUnlocked(FeatureFlag.ledgerArchiving),
      ).thenAnswer((_) async => false);

      final failure = await expectLeft(
        buildUseCase().execute(
          ledgerId: 'ledger-1',
          carryForward: const ArchiveWithCarryForwardParams(
            sourceLedgerId: 'ledger-1',
            targetLedgerId: 'target-1',
            operationId: 'op-1',
            openingBalanceItemName: 'رصيد',
            openingBalanceDescription: 'ترحيل',
          ),
        ),
      );

      expect(failure, isA<LimitExceededFailure>());
      expect(failure.code, 'ledger_archiving_tier_locked');
    });

    test('blocks same-ledger carry-forward target at use case layer', () async {
      const ledgerId = 'ledger-1';
      when(
        () => activationRepository.isFeatureUnlocked(FeatureFlag.ledgerArchiving),
      ).thenAnswer((_) async => true);

      final failure = await expectLeft(
        buildUseCase().execute(
          ledgerId: ledgerId,
          carryForward: const ArchiveWithCarryForwardParams(
            sourceLedgerId: ledgerId,
            targetLedgerId: ledgerId,
            operationId: 'op-same',
            openingBalanceItemName: 'رصيد',
            openingBalanceDescription: 'ترحيل',
          ),
        ),
      );

      expect(failure, isA<ValidationFailure>());
      expect(failure.code, 'carry_forward_same_ledger');
    });

    test('blocks archived target at use case layer', () async {
      const sourceId = 'ledger-1';
      const targetId = 'target-1';
      when(
        () => activationRepository.isFeatureUnlocked(FeatureFlag.ledgerArchiving),
      ).thenAnswer((_) async => true);
      when(() => ledgerRepository.getById(sourceId)).thenAnswer(
        (_) async => Right(liveLedger(sourceId)),
      );
      when(() => ledgerRepository.getById(targetId)).thenAnswer(
        (_) async => Right(liveLedger(targetId, isUserArchived: true)),
      );

      final failure = await expectLeft(
        buildUseCase().execute(
          ledgerId: sourceId,
          carryForward: const ArchiveWithCarryForwardParams(
            sourceLedgerId: sourceId,
            targetLedgerId: targetId,
            operationId: 'op-archived-target',
            openingBalanceItemName: 'رصيد',
            openingBalanceDescription: 'ترحيل',
          ),
        ),
      );

      expect(failure, isA<ValidationFailure>());
      expect(failure.code, 'carry_forward_invalid_target');
    });

    test('blocks rollover when contact limit would be exceeded', () async {
      const sourceId = 'ledger-1';
      const targetId = 'target-1';
      when(
        () => activationRepository.isFeatureUnlocked(FeatureFlag.ledgerArchiving),
      ).thenAnswer((_) async => true);
      when(() => ledgerRepository.getById(sourceId)).thenAnswer(
        (_) async => Right(liveLedger(sourceId)),
      );
      when(() => ledgerRepository.getById(targetId)).thenAnswer(
        (_) async => Right(liveLedger(targetId)),
      );
      when(
        () => ledgerRepository.previewCarryForward(
          sourceLedgerId: sourceId,
          targetLedgerId: targetId,
        ),
      ).thenAnswer(
        (_) async => const Right(
          CarryForwardPreview(
            contactCount: 3,
            transactionCount: 3,
            totalsByCurrency: {'YER': -300},
            sourceLedgerName: 'Source',
            targetLedgerName: 'Target',
          ),
        ),
      );
      when(
        () => contactRepository.getActiveCount(),
      ).thenAnswer((_) async => const Right(49));
      when(
        () => transactionRepository.getActiveCount(),
      ).thenAnswer((_) async => const Right(0));

      final failure = await expectLeft(
        buildUseCase().execute(
          ledgerId: sourceId,
          carryForward: const ArchiveWithCarryForwardParams(
            sourceLedgerId: sourceId,
            targetLedgerId: targetId,
            operationId: 'op-limit',
            openingBalanceItemName: 'رصيد',
            openingBalanceDescription: 'ترحيل',
          ),
        ),
      );

      expect(failure, isA<LimitExceededFailure>());
      expect(
        (failure as LimitExceededFailure).featureKey,
        AppConstants.featureUnlimitedContacts,
      );
    });

    test('blocks rollover when transaction limit would be exceeded', () async {
      const sourceId = 'ledger-1';
      const targetId = 'target-1';
      when(
        () => activationRepository.isFeatureUnlocked(FeatureFlag.ledgerArchiving),
      ).thenAnswer((_) async => true);
      when(() => ledgerRepository.getById(sourceId)).thenAnswer(
        (_) async => Right(liveLedger(sourceId)),
      );
      when(() => ledgerRepository.getById(targetId)).thenAnswer(
        (_) async => Right(liveLedger(targetId)),
      );
      when(
        () => ledgerRepository.previewCarryForward(
          sourceLedgerId: sourceId,
          targetLedgerId: targetId,
        ),
      ).thenAnswer(
        (_) async => const Right(
          CarryForwardPreview(
            contactCount: 1,
            transactionCount: 2,
            totalsByCurrency: {'YER': -100},
            sourceLedgerName: 'Source',
            targetLedgerName: 'Target',
          ),
        ),
      );
      when(
        () => contactRepository.getActiveCount(),
      ).thenAnswer((_) async => const Right(0));
      when(
        () => transactionRepository.getActiveCount(),
      ).thenAnswer((_) async => const Right(499));

      final failure = await expectLeft(
        buildUseCase().execute(
          ledgerId: sourceId,
          carryForward: const ArchiveWithCarryForwardParams(
            sourceLedgerId: sourceId,
            targetLedgerId: targetId,
            operationId: 'op-txn-limit',
            openingBalanceItemName: 'رصيد',
            openingBalanceDescription: 'ترحيل',
          ),
        ),
      );

      expect(failure, isA<LimitExceededFailure>());
      expect(
        (failure as LimitExceededFailure).featureKey,
        AppConstants.featureUnlimitedTransactions,
      );
    });
  });
}
