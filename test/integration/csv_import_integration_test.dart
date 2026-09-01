import 'dart:convert';

import 'package:daftar/application/import/import_csv_use_case.dart';
import 'package:daftar/application/workspace/activate_archived_imports_use_case.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/entities/entitlement.dart';
import 'package:daftar/domain/enums/app_tier.dart';
import 'package:daftar/domain/enums/duplicate_resolution_strategy.dart';
import 'package:daftar/domain/repositories/activation_repository.dart';
import 'package:daftar/domain/repositories/contact_repository.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import '../support/ledger_archiving_test_harness.dart';

class MockActivationRepository extends Mock implements ActivationRepository {}

Uint8List buildImportCsv(List<String> rows) {
  final buffer = StringBuffer('Name,Amount,Type,Currency,Date\n');
  rows.forEach(buffer.writeln);
  return Uint8List.fromList(utf8.encode(buffer.toString()));
}

Future<void> assertContactArchiveCounts(
  ContactRepository contactRepository, {
  required int active,
  required int archived,
}) async {
  final activeResult = await contactRepository.getActiveCount();
  final archivedResult = await contactRepository.getArchivedCount();
  expect(activeResult, Right<Failure, int>(active));
  expect(archivedResult, Right<Failure, int>(archived));
}

void main() {
  late LedgerArchivingTestHarness harness;
  late MockActivationRepository activationRepository;
  late ImportCsvUseCase importCsv;
  late ActivateArchivedImportsUseCase activateArchived;

  const freeTierTwentyContacts = Entitlement(
    tier: AppTier.free,
    activeFeatures: {},
    maxLedgers: 1,
    maxContacts: 20,
    maxTransactions: 500,
  );

  setUp(() {
    harness = LedgerArchivingTestHarness();
    activationRepository = MockActivationRepository();
    when(() => activationRepository.getEntitlement()).thenAnswer(
      (_) async => freeTierTwentyContacts,
    );
    importCsv = ImportCsvUseCase(
      contactRepository: harness.contactRepository,
      ledgerRepository: harness.ledgerRepository,
      transactionRepository: harness.transactionRepository,
      bulkWriteRepository: harness.bulkWriteRepository,
      activationRepository: activationRepository,
    );
    activateArchived = ActivateArchivedImportsUseCase(
      harness.ledgerRepository,
      harness.contactRepository,
      harness.transactionRepository,
      activationRepository,
    );
  });

  tearDown(() async {
    await harness.close();
  });

  group('CSV import integration', () {
    test('imports Arabic contacts under free-tier limit without blocking', () async {
      final ledger = await harness.seedLedger();
      final csvBytes = buildImportCsv([
        'أحمد,1000,debt,YER,2026-01-10',
        'علي,500,payment,YER,2026-01-11',
      ]);

      final result = await importCsv.execute(
        ledgerId: ledger.id,
        csvBytes: csvBytes,
        duplicateStrategy: DuplicateResolutionStrategy.skip,
      );

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('expected success'),
        (summary) {
          expect(summary.successCount, 2);
          expect(summary.failureCount, 0);
        },
      );

      final contacts = await (harness.database.select(harness.database.contacts)
            ..where((table) => table.ledgerId.equals(ledger.id)))
          .get();
      expect(contacts.length, 2);
      expect(
        contacts.map((row) => row.name).toSet(),
        {'أحمد', 'علي'},
      );
      expect(contacts.every((row) => !row.isArchived), isTrue);
    });

    test('archives overflow contacts then activates them after Pro upgrade', () async {
      final ledger = await harness.seedLedger();
      final rows = <String>[];
      for (var i = 1; i <= 30; i++) {
        rows.add('عميل $i,1000,debt,YER,2026-01-${i.toString().padLeft(2, '0')}');
      }
      final csvBytes = buildImportCsv(rows);

      final importResult = await importCsv.execute(
        ledgerId: ledger.id,
        csvBytes: csvBytes,
        duplicateStrategy: DuplicateResolutionStrategy.skip,
      );

      expect(importResult.isRight(), isTrue);
      importResult.fold(
        (_) => fail('expected success'),
        (summary) {
          expect(summary.successCount, 30);
          expect(summary.failureCount, 0);
        },
      );

      await assertContactArchiveCounts(
        harness.contactRepository,
        active: 20,
        archived: 10,
      );

      final orderedContacts = await (harness.database.select(
        harness.database.contacts,
      )..orderBy([
          (table) => OrderingTerm.asc(table.createdAt),
        ])).get();
      expect(orderedContacts.length, 30);
      expect(
        orderedContacts.take(20).every((row) => !row.isArchived),
        isTrue,
      );
      expect(
        orderedContacts.skip(20).every((row) => row.isArchived),
        isTrue,
      );

      when(() => activationRepository.getEntitlement()).thenAnswer(
        (_) async => Entitlement.forPro(),
      );

      final activationResult = await activateArchived.execute();
      expect(activationResult.isRight(), isTrue);
      activationResult.fold(
        (_) => fail('expected success'),
        (result) {
          expect(result.contactsActivated, 10);
          expect(result.haltedByLimit, isFalse);
        },
      );

      await assertContactArchiveCounts(
        harness.contactRepository,
        active: 30,
        archived: 0,
      );
    });
  });
}
