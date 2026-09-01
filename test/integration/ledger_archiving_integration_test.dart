import 'dart:convert';

import 'package:daftar/application/ledger/archive_ledger_use_case.dart';
import 'package:daftar/application/ledger/unarchive_ledger_use_case.dart';
import 'package:daftar/core/constants/db_constants.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/enums/feature_flag.dart';
import 'package:daftar/domain/repositories/activation_repository.dart';
import 'package:daftar/domain/repositories/ledger_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../support/ledger_archiving_test_harness.dart';

class MockActivationRepository extends Mock implements ActivationRepository {}

void main() {
  late LedgerArchivingTestHarness harness;
  late MockActivationRepository activationRepository;

  setUp(() {
    harness = LedgerArchivingTestHarness();
    activationRepository = MockActivationRepository();
  });

  tearDown(() async {
    await harness.close();
  });

  group('Ledger archiving integration', () {
    test('excludes archived ledger balances from global totals', () async {
      final ledger = await harness.seedLedger(name: 'دفتر الرصيد');
      final contact = await harness.seedContact(
        ledgerId: ledger.id,
        name: 'عميل الرصيد',
      );
      await harness.seedDebt(contactId: contact.id, amount: 1500);

      final beforeArchive = await harness.sumGlobalBalances();
      expect(beforeArchive[DbConstants.currencyYer], -1500);

      final archived = await expectRight(
        harness.ledgerRepository.archiveLedger(ledger.id),
      );
      expect(archived.isUserArchived, isTrue);

      final activeLedgers = await harness.ledgerRepository.watchAll().first;
      expect(activeLedgers.any((row) => row.id == ledger.id), isFalse);

      final archivedLedgers =
          await harness.ledgerRepository.watchArchived().first;
      expect(archivedLedgers.any((row) => row.id == ledger.id), isTrue);

      final duringArchive = await harness.sumGlobalBalances();
      expect(duringArchive[DbConstants.currencyYer], isNull);

      final restored = await expectRight(
        harness.ledgerRepository.unarchiveLedger(ledger.id),
      );
      expect(restored.isUserArchived, isFalse);

      final afterUnarchive = await harness.sumGlobalBalances();
      expect(afterUnarchive[DbConstants.currencyYer], -1500);
    });

    test('blocks unarchive after downgrade while vault remains readable', () async {
      when(
        () => activationRepository.isFeatureUnlocked(FeatureFlag.ledgerArchiving),
      ).thenAnswer((_) async => true);

      final ledger = await harness.seedLedger(name: 'دفتر التخفيض');
      final archiveUseCase = ArchiveLedgerUseCase(
        harness.ledgerRepository,
        harness.contactRepository,
        harness.transactionRepository,
        activationRepository,
      );

      await expectRight(
        archiveUseCase.execute(ledgerId: ledger.id),
      );

      when(
        () => activationRepository.isFeatureUnlocked(FeatureFlag.ledgerArchiving),
      ).thenAnswer((_) async => false);

      final failure = await expectLeft(
        UnarchiveLedgerUseCase(
          harness.ledgerRepository,
          activationRepository,
        ).execute(ledger.id),
      );

      expect(failure, isA<LimitExceededFailure>());
      expect(failure.code, 'ledger_archiving_tier_locked');

      final archivedLedgers =
          await harness.ledgerRepository.watchArchived().first;
      expect(archivedLedgers.single.id, ledger.id);
    });

    test('promoteArchived clears import flag but preserves user archive', () async {
      final ledger = await harness.seedLedger(name: 'دفتر العلمين');
      final contact = await harness.seedContact(
        ledgerId: ledger.id,
        name: 'عميل العلمين',
      );
      await harness.seedDebt(contactId: contact.id, amount: 900);

      await harness.setLedgerFlags(
        ledger.id,
        isArchived: true,
        isUserArchived: true,
      );

      final promoted = await expectRight(
        harness.ledgerRepository.promoteArchived(limit: 1),
      );
      expect(promoted, 1);

      final stored = await expectRight(
        harness.ledgerRepository.getById(ledger.id),
      );
      expect(stored.isArchived, isFalse);
      expect(stored.isUserArchived, isTrue);

      final activeLedgers = await harness.ledgerRepository.watchAll().first;
      expect(activeLedgers.any((row) => row.id == ledger.id), isFalse);

      final archivedLedgers =
          await harness.ledgerRepository.watchArchived().first;
      expect(archivedLedgers.any((row) => row.id == ledger.id), isTrue);

      final globalBalances = await harness.sumGlobalBalances();
      expect(globalBalances[DbConstants.currencyYer], isNull);
    });

    test('carry-forward archives source and mirrors balances on target', () async {
      const itemName = 'رصيد افتتاحي';
      const description = 'ترحيل من دفتر المصدر';
      const operationId = 'carry-forward-op-1';

      final source = await harness.seedLedger(name: 'دفتر المصدر');
      final target = await harness.seedLedger(name: 'دفتر الهدف');

      final contactA = await harness.seedContact(
        ledgerId: source.id,
        name: 'عميل أ',
      );
      final contactB = await harness.seedContact(
        ledgerId: source.id,
        name: 'عميل ب',
      );
      await harness.seedDebt(contactId: contactA.id, amount: 2000);
      await harness.seedPayment(contactId: contactB.id, amount: 500);

      final sourceBalancesBefore = await harness.balanceRepository
          .getByContact(contactA.id);
      final sourceBalanceA =
          (await expectRight(sourceBalancesBefore)).single.netBalance;
      final sourceBalancesB = await harness.balanceRepository
          .getByContact(contactB.id);
      final sourceBalanceB =
          (await expectRight(sourceBalancesB)).single.netBalance;

      final result = await expectRight(
        harness.ledgerRepository.archiveWithCarryForward(
          ArchiveWithCarryForwardParams(
            sourceLedgerId: source.id,
            targetLedgerId: target.id,
            operationId: operationId,
            openingBalanceItemName: itemName,
            openingBalanceDescription: description,
          ),
        ),
      );

      expect(result.archivedLedger.isUserArchived, isTrue);
      expect(result.archivedLedger.carryForwardTargetLedgerId, target.id);
      expect(result.contactsCreated, 2);
      expect(result.transactionsCreated, 2);
      expect(result.targetLedgerId, target.id);

      final targetContacts =
          await harness.contactRepository.watchByLedger(target.id).first;
      expect(targetContacts, hasLength(2));

      for (final targetContact in targetContacts) {
        final transactions = await expectRight(
          harness.transactionRepository.getByContact(targetContact.id),
        );
        expect(transactions, hasLength(1));
        expect(transactions.single.itemName, itemName);
        expect(transactions.single.description, description);
      }

      final targetBalanceA = await expectRight(
        harness.balanceRepository.getByContact(
          targetContacts.firstWhere((row) => row.name == 'عميل أ').id,
        ),
      );
      final targetBalanceB = await expectRight(
        harness.balanceRepository.getByContact(
          targetContacts.firstWhere((row) => row.name == 'عميل ب').id,
        ),
      );
      expect(targetBalanceA.single.netBalance, sourceBalanceA);
      expect(targetBalanceB.single.netBalance, sourceBalanceB);

      final globalDuringArchive = await harness.sumGlobalBalances();
      final expectedGlobal = sourceBalanceA + sourceBalanceB;
      expect(globalDuringArchive[DbConstants.currencyYer], expectedGlobal);

      final auditRows = await harness.database.select(harness.database.auditLogs).get();
      final replayableOps = auditRows.where((log) {
        final payload = log.payload;
        if (payload == null || payload.isEmpty) {
          return false;
        }
        final decoded = jsonDecode(payload) as Map<String, dynamic>;
        return decoded['carryForwardOperationId'] == operationId;
      }).toList();
      expect(
        replayableOps.where(
          (log) => log.entityType == 'contact' && log.action == 'CREATE',
        ),
        hasLength(2),
      );
      expect(
        replayableOps.where(
          (log) => log.entityType == 'transaction' && log.action == 'CREATE',
        ),
        hasLength(2),
      );

      final contactPayload = jsonDecode(
        replayableOps
            .firstWhere((log) => log.entityType == 'contact')
            .payload!,
      ) as Map<String, dynamic>;
      expect(contactPayload.keys, containsAll([
        'id',
        'ledgerId',
        'name',
        'phone',
        'notes',
        'creditLimit',
        'creditCurrency',
        'avatarColor',
        'carryForwardOperationId',
      ]));

      final transactionPayload = jsonDecode(
        replayableOps
            .firstWhere((log) => log.entityType == 'transaction')
            .payload!,
      ) as Map<String, dynamic>;
      expect(transactionPayload.keys, containsAll([
        'id',
        'contactId',
        'type',
        'amount',
        'currency',
        'description',
        'itemName',
        'attachmentPath',
        'transactionDate',
        'carryForwardOperationId',
      ]));

      final sourceLedgerLogs = auditRows
          .where(
            (log) => log.entityId == source.id && log.entityType == 'ledger',
          )
          .toList();
      expect(
        sourceLedgerLogs.any((log) => log.action == 'UPDATE'),
        isTrue,
      );
      expect(
        sourceLedgerLogs.any((log) => log.action == 'CARRY_FORWARD'),
        isTrue,
      );
      expect(
        sourceLedgerLogs.any((log) => log.action == 'USER_ARCHIVE'),
        isFalse,
      );

      final updatePayload = jsonDecode(
        sourceLedgerLogs.firstWhere((log) => log.action == 'UPDATE').payload!,
      ) as Map<String, dynamic>;
      expect(updatePayload['isUserArchived'], isTrue);
      expect(updatePayload['carryForwardTargetLedgerId'], target.id);

      final retry = await expectRight(
        harness.ledgerRepository.archiveWithCarryForward(
          ArchiveWithCarryForwardParams(
            sourceLedgerId: source.id,
            targetLedgerId: target.id,
            operationId: 'carry-forward-op-2',
            openingBalanceItemName: itemName,
            openingBalanceDescription: description,
          ),
        ),
      );
      expect(retry.contactsCreated, 0);
      expect(retry.transactionsCreated, 0);

      final targetContactsAfterRetry =
          await harness.contactRepository.watchByLedger(target.id).first;
      expect(targetContactsAfterRetry, hasLength(2));
    });
  });
}
