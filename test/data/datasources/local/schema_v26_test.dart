import 'dart:io';

import 'package:daftar/core/constants/db_constants.dart';
import 'package:daftar/data/datasources/local/drift_database.dart';
import 'package:daftar/data/models/contact_model.dart';
import 'package:daftar/domain/constants/drive_backup_constants.dart';
import 'package:daftar/domain/enums/call_batch_status.dart';
import 'package:daftar/domain/enums/call_batch_trigger.dart';
import 'package:daftar/domain/enums/call_run_outcome.dart';
import 'package:daftar/domain/enums/collection_promise_status.dart';
import 'package:daftar/domain/enums/ledger_type.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Schema v26 — Confirm & Call tables', () {
    late AppDatabase database;

    setUp(() {
      database = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await database.close();
    });

    test('DbConstants and DriveBackupConstants schemaVersion are 26', () {
      expect(DbConstants.schemaVersion, 26);
      expect(DriveBackupConstants.schemaVersion, 26);
      expect(database.schemaVersion, 26);
      expect(
        DbConstants.schemaVersion,
        DriveBackupConstants.schemaVersion,
      );
    });

    test('collection batch, run, and promise persist integer money', () async {
      final now = DateTime.utc(2026, 9, 2, 12);

      await database.into(database.ledgers).insert(
        LedgersCompanion.insert(
          id: 'ledger-v26',
          name: 'Customers',
          type: LedgerType.customers,
          icon: 'store',
          color: '#6E6E76',
          sortOrder: 0,
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      await database.into(database.contacts).insert(
        ContactModel(
          id: 'contact-v26',
          ledgerId: 'ledger-v26',
          name: 'Test Contact',
          phone: null,
          notes: null,
          creditLimit: null,
          creditCurrency: null,
          avatarColor: '#6E6E76',
          createdAt: now,
          updatedAt: now,
        ).toDrift(),
      );

      const batchId = 'batch-uuid-v26';
      const runId = 'run-uuid-calle';

      await database.into(database.collectionCallBatches).insert(
        CollectionCallBatchesCompanion.insert(
          id: 'batch-row-v26',
          batchId: batchId,
          correlationId: 'corr-v26',
          trigger: CallBatchTrigger.closeDay,
          status: CallBatchStatus.planned,
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      await database.into(database.collectionCallRuns).insert(
        CollectionCallRunsCompanion.insert(
          id: 'run-row-v26',
          batchId: batchId,
          contactId: 'contact-v26',
          region: 'YE',
          locale: 'ar',
          runId: Value(runId),
          outcome: Value(CallRunOutcome.promised),
          promisedAmountMinor: const Value(500),
          promisedCurrency: const Value('YER'),
          promisedDate: const Value('2026-09-05'),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      await database.into(database.collectionPromises).insert(
        CollectionPromisesCompanion.insert(
          id: 'promise-row-v26',
          contactId: 'contact-v26',
          runId: runId,
          amountMinor: 500,
          currencyCode: 'YER',
          promisedDate: '2026-09-05',
          status: CollectionPromiseStatus.pending,
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      final batch = await (database.select(database.collectionCallBatches)
            ..where((row) => row.batchId.equals(batchId)))
          .getSingle();
      expect(batch.status, CallBatchStatus.planned);

      final run = await (database.select(database.collectionCallRuns)
            ..where((row) => row.runId.equals(runId)))
          .getSingle();
      expect(run.promisedAmountMinor, 500);
      expect(run.promisedAmountMinor, isA<int>());

      final promise = await (database.select(database.collectionPromises)
            ..where((row) => row.runId.equals(runId)))
          .getSingle();
      expect(promise.amountMinor, 500);
      expect(promise.amountMinor, isA<int>());
    });

    test('doNotCall defaults false on new contact', () async {
      final now = DateTime.utc(2026, 9, 2, 12);

      await database.into(database.ledgers).insert(
        LedgersCompanion.insert(
          id: 'ledger-dnc-default',
          name: 'Customers',
          type: LedgerType.customers,
          icon: 'store',
          color: '#6E6E76',
          sortOrder: 0,
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      await database.into(database.contacts).insert(
        ContactModel(
          id: 'contact-dnc-default',
          ledgerId: 'ledger-dnc-default',
          name: 'Callable',
          phone: null,
          notes: null,
          creditLimit: null,
          creditCurrency: null,
          avatarColor: '#6E6E76',
          createdAt: now,
          updatedAt: now,
        ).toDrift(),
      );

      final row = await (database.select(database.contacts)
            ..where((c) => c.id.equals('contact-dnc-default')))
          .getSingle();
      expect(row.doNotCall, isFalse);
    });

    test('doNotCall true survives domain → Drift → domain round-trip', () {
      final now = DateTime.utc(2026, 9, 2, 12);
      final model = ContactModel(
        id: 'contact-dnc-true',
        ledgerId: 'ledger-dnc',
        name: 'Do Not Call',
        phone: null,
        notes: null,
        creditLimit: null,
        creditCurrency: null,
        avatarColor: '#6E6E76',
        createdAt: now,
        updatedAt: now,
        doNotCall: true,
      );

      final roundTripped = ContactModel.fromDrift(model.toDrift()).toDomain();
      expect(roundTripped.doNotCall, isTrue);
    });

    test('sqlite_master contains collection call tables', () async {
      final rows = await database
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type='table' "
            "AND name IN ("
            "'collection_call_batches', "
            "'collection_call_runs', "
            "'collection_promises'"
            ')',
          )
          .get();

      final names = rows.map((row) => row.data['name'] as String).toSet();
      expect(
        names,
        {
          'collection_call_batches',
          'collection_call_runs',
          'collection_promises',
        },
      );
    });

    test('collection table sources use IntColumn only for money', () {
      const tablePaths = [
        'lib/data/datasources/local/tables/collection_call_batches_table.dart',
        'lib/data/datasources/local/tables/collection_call_runs_table.dart',
        'lib/data/datasources/local/tables/collection_promises_table.dart',
      ];

      for (final path in tablePaths) {
        final source = File(path).readAsStringSync();
        expect(
          source.contains('RealColumn'),
          isFalse,
          reason: '$path must not use RealColumn for money',
        );
      }
    });
  });
}
