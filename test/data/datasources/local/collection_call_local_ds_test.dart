import 'package:daftar/data/datasources/local/collection_call_local_ds.dart';
import 'package:daftar/data/datasources/local/drift_database.dart';
import 'package:daftar/data/models/contact_model.dart';
import 'package:daftar/domain/enums/call_batch_status.dart';
import 'package:daftar/domain/enums/call_batch_trigger.dart';
import 'package:daftar/domain/enums/call_run_outcome.dart';
import 'package:daftar/domain/enums/collection_promise_status.dart';
import 'package:daftar/domain/enums/ledger_type.dart';
import 'package:daftar/domain/value_objects/collection_call_persist.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late CollectionCallLocalDataSource local;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    local = CollectionCallLocalDataSource(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('persists runId then integer promise on terminal promised', () async {
    final now = DateTime.utc(2026, 9, 4, 12);
    await database.into(database.ledgers).insert(
      LedgersCompanion.insert(
        id: 'ledger-call',
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
        id: 'contact-call',
        ledgerId: 'ledger-call',
        name: 'Mohamed',
        phone: null,
        notes: null,
        creditLimit: null,
        creditCurrency: null,
        avatarColor: '#6E6E76',
        createdAt: now,
        updatedAt: now,
      ).toDrift(),
    );

    await local.persistQueuedBatch(
      const CollectionCallBatchSeed(
        batchId: 'batch-1',
        correlationId: 'corr-1',
        trigger: CallBatchTrigger.closeDay,
        status: CallBatchStatus.running,
        runs: [
          CollectionCallRunSeed(
            contactId: 'contact-call',
            region: 'US',
            locale: 'en',
            runId: 'calle-run-1',
          ),
        ],
      ),
    );

    await local.persistTerminalWrite(
      const CollectionCallTerminalWrite(
        runId: 'calle-run-1',
        contactId: 'contact-call',
        rawStatus: 'completed',
        needsHuman: false,
        outcome: CallRunOutcome.promised,
        promisedAmountMinor: 1500,
        promisedCurrency: 'USD',
        promisedDate: '2026-09-10',
      ),
    );

    final run = await (database.select(database.collectionCallRuns)
          ..where((row) => row.runId.equals('calle-run-1')))
        .getSingle();
    expect(run.promisedAmountMinor, 1500);
    expect(run.promisedAmountMinor, isA<int>());

    final promise = await (database.select(database.collectionPromises)
          ..where((row) => row.runId.equals('calle-run-1')))
        .getSingle();
    expect(promise.amountMinor, 1500);
    expect(promise.status, CollectionPromiseStatus.pending);
  });

  test('does not upsert promise when amount has remainder flag', () async {
    final now = DateTime.utc(2026, 9, 4, 12);
    await database.into(database.ledgers).insert(
      LedgersCompanion.insert(
        id: 'ledger-call-2',
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
        id: 'contact-call-2',
        ledgerId: 'ledger-call-2',
        name: 'Mohamed',
        phone: null,
        notes: null,
        creditLimit: null,
        creditCurrency: null,
        avatarColor: '#6E6E76',
        createdAt: now,
        updatedAt: now,
      ).toDrift(),
    );

    await local.persistQueuedBatch(
      const CollectionCallBatchSeed(
        batchId: 'batch-2',
        correlationId: 'corr-2',
        trigger: CallBatchTrigger.closeDay,
        status: CallBatchStatus.running,
        runs: [
          CollectionCallRunSeed(
            contactId: 'contact-call-2',
            region: 'US',
            locale: 'en',
            runId: 'calle-run-2',
          ),
        ],
      ),
    );

    await local.persistTerminalWrite(
      const CollectionCallTerminalWrite(
        runId: 'calle-run-2',
        contactId: 'contact-call-2',
        rawStatus: 'completed',
        needsHuman: true,
        outcome: CallRunOutcome.promised,
        amountInvalid: true,
      ),
    );

    final promises = await database.select(database.collectionPromises).get();
    expect(promises, isEmpty);
  });
}
