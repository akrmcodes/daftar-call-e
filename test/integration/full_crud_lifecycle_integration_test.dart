import 'package:daftar/application/contact/check_credit_limit_use_case.dart';
import 'package:daftar/application/contact/create_contact_use_case.dart';
import 'package:daftar/application/contact/update_contact_use_case.dart';
import 'package:daftar/application/ledger/archive_ledger_use_case.dart';
import 'package:daftar/application/ledger/create_ledger_use_case.dart';
import 'package:daftar/application/transaction/add_transaction_use_case.dart';
import 'package:daftar/application/transaction/delete_transaction_use_case.dart';
import 'package:daftar/application/transaction/update_transaction_use_case.dart';
import 'package:daftar/core/constants/db_constants.dart';
import 'package:daftar/data/repositories/balance_repository_impl.dart';
import 'package:daftar/domain/entities/entitlement.dart';
import 'package:daftar/domain/enums/feature_flag.dart';
import 'package:daftar/domain/enums/ledger_type.dart';
import 'package:daftar/domain/enums/transaction_type.dart';
import 'package:daftar/domain/repositories/activation_repository.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../support/ledger_archiving_test_harness.dart';

class MockActivationRepository extends Mock implements ActivationRepository {}

Future<int> yerNetForContact(
  BalanceRepositoryImpl repository,
  String contactId,
) async {
  final balances = await expectRight(repository.getByContact(contactId));
  if (balances.isEmpty) {
    return 0;
  }
  return balances
      .where((row) => row.currencyCode == DbConstants.currencyYer)
      .fold<int>(0, (sum, row) => sum + row.netBalance);
}

Future<int> yerGlobalTotal(BalanceRepositoryImpl repository) async {
  final rows = await repository.watchAllBalances().first;
  return rows
      .where((row) => row.currencyCode == DbConstants.currencyYer)
      .fold<int>(0, (sum, row) => sum + row.netBalance);
}

Future<int> yerLedgerTotal(
  BalanceRepositoryImpl repository,
  String ledgerId,
) async {
  final rows = await repository.watchBalancesByLedger(ledgerId).first;
  return rows
      .where((row) => row.currencyCode == DbConstants.currencyYer)
      .fold<int>(0, (sum, row) => sum + row.netBalance);
}

void main() {
  late LedgerArchivingTestHarness harness;
  late MockActivationRepository activationRepository;
  late CreateLedgerUseCase createLedgerUseCase;
  late CreateContactUseCase createContactUseCase;
  late UpdateContactUseCase updateContactUseCase;
  late AddTransactionUseCase addTransactionUseCase;
  late UpdateTransactionUseCase updateTransactionUseCase;
  late DeleteTransactionUseCase deleteTransactionUseCase;
  late ArchiveLedgerUseCase archiveLedgerUseCase;

  setUp(() {
    harness = LedgerArchivingTestHarness();
    activationRepository = MockActivationRepository();
    when(() => activationRepository.getEntitlement()).thenAnswer(
      (_) async => Entitlement.forPro(),
    );
    when(
      () => activationRepository.isFeatureUnlocked(FeatureFlag.ledgerArchiving),
    ).thenAnswer((_) async => true);

    final checkCreditLimitUseCase = CheckCreditLimitUseCase(
      harness.contactRepository,
      harness.balanceRepository,
    );

    createLedgerUseCase = CreateLedgerUseCase(
      harness.ledgerRepository,
      activationRepository,
    );
    createContactUseCase = CreateContactUseCase(
      harness.contactRepository,
      harness.ledgerRepository,
      activationRepository,
    );
    updateContactUseCase = UpdateContactUseCase(
      harness.contactRepository,
      harness.ledgerRepository,
    );
    addTransactionUseCase = AddTransactionUseCase(
      harness.transactionRepository,
      harness.contactRepository,
      harness.ledgerRepository,
      checkCreditLimitUseCase,
      activationRepository,
    );
    updateTransactionUseCase = UpdateTransactionUseCase(
      harness.transactionRepository,
      harness.contactRepository,
      harness.ledgerRepository,
      checkCreditLimitUseCase,
    );
    deleteTransactionUseCase = DeleteTransactionUseCase(
      harness.transactionRepository,
      harness.contactRepository,
      harness.ledgerRepository,
    );
    archiveLedgerUseCase = ArchiveLedgerUseCase(
      harness.ledgerRepository,
      harness.contactRepository,
      harness.transactionRepository,
      activationRepository,
    );
  });

  tearDown(() async {
    await harness.close();
  });

  group('Full CRUD lifecycle integration', () {
    test('merchant lifecycle across ledger contact transaction balance', () async {
      final ledger = await expectRight(
        createLedgerUseCase.execute(
          name: 'دفتر التكامل',
          type: LedgerType.custom,
          icon: 'store',
          color: 0x1565C0,
        ),
      );

      final contact = await expectRight(
        createContactUseCase.execute(
          ledgerId: ledger.id,
          name: 'عميل التكامل',
          avatarColor: '#FF9800',
        ),
      );

      expect(await yerNetForContact(harness.balanceRepository, contact.id), 0);

      final debtResult = await expectRight(
        addTransactionUseCase.execute(
          contactId: contact.id,
          type: TransactionType.debt,
          amount: 500,
          currency: DbConstants.currencyYer,
          description: 'دين',
          itemName: 'بضاعة',
          transactionDate: DateTime.utc(2026, 6, 17),
        ),
      );
      final debtTransaction = debtResult.transaction;

      expect(await yerNetForContact(harness.balanceRepository, contact.id), -500);

      final paymentResult = await expectRight(
        addTransactionUseCase.execute(
          contactId: contact.id,
          type: TransactionType.payment,
          amount: 200,
          currency: DbConstants.currencyYer,
          description: 'دفعة',
          transactionDate: DateTime.utc(2026, 6, 18),
        ),
      );
      final paymentTransaction = paymentResult.transaction;

      expect(await yerNetForContact(harness.balanceRepository, contact.id), -300);
      expect(
        await harness.balanceRepository.watchByContact(contact.id).first,
        hasLength(1),
      );
      expect(
        (await harness.balanceRepository.watchByContact(contact.id).first)
            .single
            .netBalance,
        -300,
      );
      expect(await yerLedgerTotal(harness.balanceRepository, ledger.id), -300);
      expect(await yerGlobalTotal(harness.balanceRepository), -300);

      final updatedDebtResult = await expectRight(
        updateTransactionUseCase.execute(
          UpdateTransactionParams(
            id: debtTransaction.id,
            amount: 600,
          ),
        ),
      );
      expect(updatedDebtResult.transaction.amount, 600);
      expect(await yerNetForContact(harness.balanceRepository, contact.id), -400);

      final renamedContact = await expectRight(
        updateContactUseCase.execute(
          contact.copyWith(name: 'عميل محدث'),
        ),
      );
      expect(renamedContact.name, 'عميل محدث');
      expect(
        (await expectRight(harness.contactRepository.getById(contact.id))).name,
        'عميل محدث',
      );

      await expectRight(
        deleteTransactionUseCase.execute(
          DeleteTransactionParams(id: paymentTransaction.id),
        ),
      );
      expect(await yerNetForContact(harness.balanceRepository, contact.id), -600);

      await expectRight(harness.contactRepository.delete(contact.id));
      expect(
        await expectRight(
          harness.balanceRepository.getByContact(contact.id),
        ),
        isEmpty,
      );
      expect(await yerGlobalTotal(harness.balanceRepository), 0);

      final archiveContact = await expectRight(
        createContactUseCase.execute(
          ledgerId: ledger.id,
          name: 'عميل الأرشيف',
          avatarColor: '#009688',
        ),
      );

      final archiveDebtResult = await expectRight(
        addTransactionUseCase.execute(
          contactId: archiveContact.id,
          type: TransactionType.debt,
          amount: 800,
          currency: DbConstants.currencyYer,
          description: 'دين أرشيف',
          transactionDate: DateTime.utc(2026, 6, 19),
        ),
      );
      final archiveDebtTransaction = archiveDebtResult.transaction;
      expect(await yerGlobalTotal(harness.balanceRepository), -800);

      final archivedLedger = await expectRight(
        archiveLedgerUseCase.execute(ledgerId: ledger.id),
      );
      expect(archivedLedger.isUserArchived, isTrue);
      expect(await yerGlobalTotal(harness.balanceRepository), 0);

      final activeLedgers =
          await harness.ledgerRepository.watchAll().first;
      expect(activeLedgers.any((row) => row.id == ledger.id), isFalse);

      final auditRows = await (harness.database.select(harness.database.auditLogs)
            ..orderBy([
              (table) => drift.OrderingTerm(expression: table.timestamp),
            ]))
          .get();

      expect(auditRows, hasLength(11));
      expect(
        auditRows.map((row) => (row.entityType, row.action)).toList(),
        [
          ('ledger', 'CREATE'),
          ('contact', 'CREATE'),
          ('transaction', 'CREATE'),
          ('transaction', 'CREATE'),
          ('transaction', 'UPDATE'),
          ('contact', 'UPDATE'),
          ('transaction', 'DELETE'),
          ('contact', 'DELETE'),
          ('contact', 'CREATE'),
          ('transaction', 'CREATE'),
          ('ledger', 'USER_ARCHIVE'),
        ],
      );

      expect(auditRows[0].entityId, ledger.id);
      expect(auditRows[1].entityId, contact.id);
      expect(auditRows[2].entityId, debtTransaction.id);
      expect(auditRows[3].entityId, paymentTransaction.id);
      expect(auditRows[4].entityId, debtTransaction.id);
      expect(auditRows[5].entityId, contact.id);
      expect(auditRows[6].entityId, paymentTransaction.id);
      expect(auditRows[7].entityId, contact.id);
      expect(auditRows[8].entityId, archiveContact.id);
      expect(auditRows[9].entityId, archiveDebtTransaction.id);
      expect(auditRows[10].entityId, ledger.id);
    });
  });
}
