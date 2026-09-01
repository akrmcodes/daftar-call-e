import 'package:daftar/domain/repositories/ledger_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/carry_forward_op_log_replay.dart';
import '../support/ledger_archiving_test_harness.dart';

void main() {
  group('Carry forward sync simulation', () {
    test('replays CREATE and UPDATE audit logs onto a blank device', () async {
      final sourceHarness = LedgerArchivingTestHarness();
      final replayHarness = LedgerArchivingTestHarness();

      try {
        const operationId = 'sync-sim-op-1';
        final source = await sourceHarness.seedLedger(name: 'دفتر المصدر');
        final target = await sourceHarness.seedLedger(name: 'دفتر الهدف');

        final contactA = await sourceHarness.seedContact(
          ledgerId: source.id,
          name: 'عميل أ',
        );
        final contactB = await sourceHarness.seedContact(
          ledgerId: source.id,
          name: 'عميل ب',
        );
        await sourceHarness.seedDebt(contactId: contactA.id, amount: 1800);
        await sourceHarness.seedPayment(contactId: contactB.id, amount: 600);

        await expectRight(
          sourceHarness.ledgerRepository.archiveWithCarryForward(
            ArchiveWithCarryForwardParams(
              sourceLedgerId: source.id,
              targetLedgerId: target.id,
              operationId: operationId,
              openingBalanceItemName: 'رصيد افتتاحي',
              openingBalanceDescription: 'ترحيل',
            ),
          ),
        );

        final expectedSnapshot =
            await sourceHarness.snapshotLedgerBalances(target.id);
        final auditLogs =
            await sourceHarness.database.select(sourceHarness.database.auditLogs).get();

        await seedLedgerWithId(
          replayHarness,
          id: source.id,
          name: source.name,
        );
        await seedLedgerWithId(
          replayHarness,
          id: target.id,
          name: target.name,
        );

        final firstReplay = await replayCarryForwardAuditLogs(
          harness: replayHarness,
          auditLogs: auditLogs,
          operationId: operationId,
        );
        expect(firstReplay.appliedCount, greaterThan(0));
        expect(firstReplay.skippedCount, 0);

        final replayedSnapshot =
            await replayHarness.snapshotLedgerBalances(target.id);
        expect(replayedSnapshot, expectedSnapshot);
        expect(await replayHarness.isLedgerUserArchived(source.id), isTrue);
        expect(
          await replayHarness.carryForwardTargetLedgerId(source.id),
          target.id,
        );

        final contactCountAfterFirst =
            await replayHarness.countContactsInLedger(target.id);

        final secondReplay = await replayCarryForwardAuditLogs(
          harness: replayHarness,
          auditLogs: auditLogs,
          operationId: operationId,
        );
        expect(secondReplay.appliedCount, 0);
        expect(secondReplay.skippedCount, greaterThan(0));
        expect(
          await replayHarness.countContactsInLedger(target.id),
          contactCountAfterFirst,
        );
        expect(
          await replayHarness.snapshotLedgerBalances(target.id),
          expectedSnapshot,
        );
      } finally {
        await sourceHarness.close();
        await replayHarness.close();
      }
    });
  });
}
