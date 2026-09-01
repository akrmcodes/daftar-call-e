import 'package:daftar/core/constants/db_constants.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/data/repositories/ledger_repository_impl.dart';
import 'package:daftar/domain/enums/transaction_type.dart';
import 'package:daftar/domain/repositories/ledger_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/ledger_archiving_test_harness.dart';

void main() {
  late LedgerArchivingTestHarness harness;

  setUp(() {
    harness = LedgerArchivingTestHarness();
  });

  tearDown(() async {
    await harness.close();
  });

  group('Financial close integration', () {
    test('carry forward five contacts with exact balance parity', () async {
      final source = await harness.seedLedger(name: 'دفتر المصدر');
      final target = await harness.seedLedger(name: 'دفتر الهدف');

      final contacts = <String, String>{};
      contacts['عميل ١'] = (await harness.seedContact(
        ledgerId: source.id,
        name: 'عميل ١',
      )).id;
      contacts['عميل ٢'] = (await harness.seedContact(
        ledgerId: source.id,
        name: 'عميل ٢',
      )).id;
      contacts['عميل ٣'] = (await harness.seedContact(
        ledgerId: source.id,
        name: 'عميل ٣',
      )).id;
      contacts['عميل ٤'] = (await harness.seedContact(
        ledgerId: source.id,
        name: 'عميل ٤',
      )).id;
      contacts['عميل ٥'] = (await harness.seedContact(
        ledgerId: source.id,
        name: 'عميل ٥',
      )).id;

      await harness.seedDebt(contactId: contacts['عميل ١']!, amount: 1200);
      await harness.seedPayment(contactId: contacts['عميل ٢']!, amount: 400);
      await harness.seedDebt(
        contactId: contacts['عميل ٣']!,
        amount: 900,
        currency: DbConstants.currencyUsd,
      );
      await harness.seedPayment(
        contactId: contacts['عميل ٤']!,
        amount: 250,
        currency: DbConstants.currencySar,
      );
      await harness.seedDebt(contactId: contacts['عميل ٥']!, amount: 50);

      final sourceSnapshot = await harness.snapshotLedgerBalances(source.id);
      final globalBefore = await harness.sumGlobalBalances();

      final result = await expectRight(
        harness.ledgerRepository.archiveWithCarryForward(
          ArchiveWithCarryForwardParams(
            sourceLedgerId: source.id,
            targetLedgerId: target.id,
            operationId: 'financial-close-5',
            openingBalanceItemName: 'رصيد افتتاحي',
            openingBalanceDescription: 'ترحيل من المصدر',
          ),
        ),
      );

      expect(result.contactsCreated, 5);
      expect(result.transactionsCreated, 5);
      expect(await harness.isLedgerUserArchived(source.id), isTrue);
      expect(await harness.carryForwardTargetLedgerId(source.id), target.id);

      final targetSnapshot = await harness.snapshotLedgerBalances(target.id);
      expect(targetSnapshot, sourceSnapshot);

      final globalAfter = await harness.sumGlobalBalances();
      expect(globalAfter, globalBefore);
    });

    test('archive-only vaults source and leaves target untouched', () async {
      final source = await harness.seedLedger(name: 'دفتر المصدر');
      final target = await harness.seedLedger(name: 'دفتر الهدف');
      final contact = await harness.seedContact(
        ledgerId: source.id,
        name: 'مدين',
      );
      await harness.seedDebt(contactId: contact.id, amount: 700);

      final targetContactsBefore = await harness.countContactsInLedger(target.id);
      final targetSnapshotBefore = await harness.snapshotLedgerBalances(target.id);

      final archived = await expectRight(
        harness.ledgerRepository.archiveLedger(source.id),
      );

      expect(archived.isUserArchived, isTrue);
      expect(await harness.countContactsInLedger(target.id), targetContactsBefore);
      expect(
        await harness.snapshotLedgerBalances(target.id),
        targetSnapshotBefore,
      );
      expect(await harness.carryForwardTargetLedgerId(source.id), isNull);
    });

    test('rolls back entirely when fault injected mid transaction', () async {
      await harness.close();
      harness = LedgerArchivingTestHarness(
        carryForwardTestFaults: const CarryForwardTestFaults(
          throwBeforeNewContactInsertAt: 2,
        ),
      );

      final source = await harness.seedLedger(name: 'دفتر المصدر');
      final target = await harness.seedLedger(name: 'دفتر الهدف');
      final targetContactsBefore = await harness.countContactsInLedger(target.id);

      for (var index = 1; index <= 5; index++) {
        final contact = await harness.seedContact(
          ledgerId: source.id,
          name: 'عميل $index',
        );
        await harness.seedDebt(contactId: contact.id, amount: 100 * index);
      }

      final failure = await expectLeft(
        harness.ledgerRepository.archiveWithCarryForward(
          ArchiveWithCarryForwardParams(
            sourceLedgerId: source.id,
            targetLedgerId: target.id,
            operationId: 'crash-sim',
            openingBalanceItemName: 'رصيد افتتاحي',
            openingBalanceDescription: 'ترحيل',
          ),
        ),
      );

      expect(failure, isA<DatabaseFailure>());
      expect(await harness.countContactsInLedger(target.id), targetContactsBefore);
      expect(await harness.isLedgerUserArchived(source.id), isFalse);
      expect(await harness.carryForwardTargetLedgerId(source.id), isNull);

      final targetContacts =
          await harness.contactRepository.watchByLedger(target.id).first;
      for (final row in targetContacts) {
        final transactions = await expectRight(
          harness.transactionRepository.getByContact(row.id),
        );
        expect(transactions, isEmpty);
      }
    });

    test('retries are idempotent without duplicate rows', () async {
      final source = await harness.seedLedger(name: 'دفتر المصدر');
      final target = await harness.seedLedger(name: 'دفتر الهدف');

      for (var index = 1; index <= 3; index++) {
        final contact = await harness.seedContact(
          ledgerId: source.id,
          name: 'عميل $index',
        );
        await harness.seedBalance(
          contactId: contact.id,
          type: index.isEven ? TransactionType.payment : TransactionType.debt,
          amount: 200 * index,
        );
      }

      await expectRight(
        harness.ledgerRepository.archiveWithCarryForward(
          ArchiveWithCarryForwardParams(
            sourceLedgerId: source.id,
            targetLedgerId: target.id,
            operationId: 'idem-op-1',
            openingBalanceItemName: 'رصيد افتتاحي',
            openingBalanceDescription: 'ترحيل',
          ),
        ),
      );

      final contactsAfterFirst = await harness.countContactsInLedger(target.id);

      final retry = await expectRight(
        harness.ledgerRepository.archiveWithCarryForward(
          ArchiveWithCarryForwardParams(
            sourceLedgerId: source.id,
            targetLedgerId: target.id,
            operationId: 'idem-op-2',
            openingBalanceItemName: 'رصيد افتتاحي',
            openingBalanceDescription: 'ترحيل',
          ),
        ),
      );

      expect(retry.contactsCreated, 0);
      expect(retry.transactionsCreated, 0);
      expect(
        await harness.countContactsInLedger(target.id),
        contactsAfterFirst,
      );
    });
  });
}
