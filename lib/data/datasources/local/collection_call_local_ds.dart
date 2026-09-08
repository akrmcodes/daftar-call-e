import 'package:daftar/core/errors/exceptions.dart';
import 'package:daftar/core/utils/uuid_util.dart';
import 'package:daftar/data/datasources/local/drift_database.dart' as db;
import 'package:daftar/domain/enums/call_batch_status.dart';
import 'package:daftar/domain/enums/collection_promise_status.dart';
import 'package:daftar/domain/value_objects/collection_call_persist.dart';
import 'package:drift/drift.dart';

/// Drift persistence for Confirm & Call runs and display-only promises.
class CollectionCallLocalDataSource {
  /// Creates the data source.
  CollectionCallLocalDataSource(this.database);

  /// Drift database.
  final db.AppDatabase database;

  /// Inserts the batch header and queued runs atomically.
  Future<void> persistQueuedBatch(CollectionCallBatchSeed seed) async {
    final now = DateTime.now().toUtc();
    await database.transaction(() async {
      final existingBatch =
          await (database.select(database.collectionCallBatches)
                ..where((row) => row.batchId.equals(seed.batchId)))
              .getSingleOrNull();
      if (existingBatch != null) {
        await (database.update(database.collectionCallBatches)
              ..where((row) => row.id.equals(existingBatch.id)))
            .write(
          db.CollectionCallBatchesCompanion(
            correlationId: Value(seed.correlationId),
            trigger: Value(seed.trigger),
            status: Value(seed.status),
            updatedAt: Value(now),
          ),
        );
      } else {
        await database.into(database.collectionCallBatches).insert(
          db.CollectionCallBatchesCompanion.insert(
            id: UuidUtil.generate(),
            batchId: seed.batchId,
            correlationId: seed.correlationId,
            trigger: seed.trigger,
            status: seed.status,
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
      }

      for (final run in seed.runs) {
        final existingRun =
            await (database.select(database.collectionCallRuns)
                  ..where((row) => row.runId.equals(run.runId)))
                .getSingleOrNull();
        if (existingRun != null) {
          await (database.update(database.collectionCallRuns)
                ..where((row) => row.id.equals(existingRun.id)))
              .write(
            db.CollectionCallRunsCompanion(
              batchId: Value(seed.batchId),
              contactId: Value(run.contactId),
              region: Value(run.region),
              locale: Value(run.locale),
              retryCount: Value(run.retryCount),
              updatedAt: Value(now),
            ),
          );
          continue;
        }
        await database.into(database.collectionCallRuns).insert(
          db.CollectionCallRunsCompanion.insert(
            id: UuidUtil.generate(),
            batchId: seed.batchId,
            contactId: run.contactId,
            region: run.region,
            locale: run.locale,
            runId: Value(run.runId),
            retryCount: Value(run.retryCount),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
      }
    });
  }

  /// Updates a run from a terminal GET. Upserts a promise when valid.
  Future<void> persistTerminalWrite(CollectionCallTerminalWrite write) async {
    final now = DateTime.now().toUtc();
    await database.transaction(() async {
      final existing =
          await (database.select(database.collectionCallRuns)
                ..where((row) => row.runId.equals(write.runId)))
              .getSingleOrNull();
      if (existing != null) {
        await (database.update(database.collectionCallRuns)
              ..where((row) => row.id.equals(existing.id)))
            .write(
          db.CollectionCallRunsCompanion(
            outcome: Value(write.outcome),
            promisedAmountMinor: Value(write.promisedAmountMinor),
            promisedCurrency: Value(write.promisedCurrency),
            promisedDate: Value(write.promisedDate),
            acknowledgedHold: Value(write.acknowledgedHold),
            evidenceQuote: Value(write.evidenceQuote),
            rawStatus: Value(write.rawStatus),
            updatedAt: Value(now),
          ),
        );
      } else {
        await database.into(database.collectionCallRuns).insert(
          db.CollectionCallRunsCompanion.insert(
            id: UuidUtil.generate(),
            batchId: write.runId,
            contactId: write.contactId,
            region: '',
            locale: '',
            runId: Value(write.runId),
            outcome: Value(write.outcome),
            promisedAmountMinor: Value(write.promisedAmountMinor),
            promisedCurrency: Value(write.promisedCurrency),
            promisedDate: Value(write.promisedDate),
            acknowledgedHold: Value(write.acknowledgedHold),
            evidenceQuote: Value(write.evidenceQuote),
            rawStatus: Value(write.rawStatus),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
      }

      final batchId = existing?.batchId;
      if (batchId != null && batchId.isNotEmpty) {
        await _maybeFinalizeBatchStatus(batchId, now, write.needsHuman);
      }

      if (!write.shouldUpsertPromise) {
        return;
      }

      final existingPromise =
          await (database.select(database.collectionPromises)
                ..where((row) => row.runId.equals(write.runId)))
              .getSingleOrNull();
      if (existingPromise != null) {
        await (database.update(database.collectionPromises)
              ..where((row) => row.id.equals(existingPromise.id)))
            .write(
          db.CollectionPromisesCompanion(
            amountMinor: Value(write.promisedAmountMinor!),
            currencyCode: Value(write.promisedCurrency!),
            promisedDate: Value(write.promisedDate!),
            status: Value(
              existingPromise.status == CollectionPromiseStatus.pending
                  ? CollectionPromiseStatus.pending
                  : existingPromise.status,
            ),
            updatedAt: Value(now),
            isDeleted: const Value(false),
            syncVersion: Value(existingPromise.syncVersion + 1),
          ),
        );
        return;
      }

      await database.into(database.collectionPromises).insert(
        db.CollectionPromisesCompanion.insert(
          id: UuidUtil.generate(),
          contactId: write.contactId,
          runId: write.runId,
          amountMinor: write.promisedAmountMinor!,
          currencyCode: write.promisedCurrency!,
          promisedDate: write.promisedDate!,
          status: CollectionPromiseStatus.pending,
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
    });
  }

  /// Watches non-deleted pending promises for a contact.
  Stream<List<db.CollectionPromise>> watchPendingPromisesByContact(
    String contactId,
  ) {
    return (database.select(database.collectionPromises)
          ..where(
            (row) =>
                row.contactId.equals(contactId) &
                row.status.equalsValue(CollectionPromiseStatus.pending) &
                row.isDeleted.equals(false),
          )
          ..orderBy([
            (row) => OrderingTerm(
              expression: row.updatedAt,
              mode: OrderingMode.desc,
            ),
          ]))
        .watch();
  }

  /// Loads a non-deleted promise row by primary key.
  Future<db.CollectionPromise?> getPromiseById(String promiseId) {
    return (database.select(database.collectionPromises)
          ..where(
            (row) =>
                row.id.equals(promiseId) & row.isDeleted.equals(false),
          ))
        .getSingleOrNull();
  }

  /// Writes merchant-resolved [status] and bumps sync version.
  Future<db.CollectionPromise> writePromiseStatus({
    required String promiseId,
    required CollectionPromiseStatus status,
    required DateTime updatedAt,
  }) async {
    final existing = await getPromiseById(promiseId);
    if (existing == null) {
      throw DatabaseException('Collection promise not found: $promiseId');
    }
    await (database.update(database.collectionPromises)
          ..where((row) => row.id.equals(promiseId)))
        .write(
      db.CollectionPromisesCompanion(
        status: Value(status),
        updatedAt: Value(updatedAt),
        syncVersion: Value(existing.syncVersion + 1),
      ),
    );
    final updated = await getPromiseById(promiseId);
    if (updated == null) {
      throw DatabaseException('Collection promise not found after update');
    }
    return updated;
  }

  Future<void> _maybeFinalizeBatchStatus(
    String batchId,
    DateTime now,
    bool currentNeedsHuman,
  ) async {
    final allRuns = await (database.select(database.collectionCallRuns)
          ..where((row) => row.batchId.equals(batchId)))
        .get();
    if (allRuns.isEmpty) {
      return;
    }
    final allTerminal = allRuns.every((run) {
      final status = run.rawStatus?.trim() ?? '';
      return status.isNotEmpty;
    });
    if (!allTerminal) {
      return;
    }
    final failed = currentNeedsHuman ||
        allRuns.any((run) {
          final status = run.rawStatus!.trim();
          return status == 'timeout' ||
              status == 'failed' ||
              status == 'canceled';
        });
    await (database.update(database.collectionCallBatches)
          ..where((row) => row.batchId.equals(batchId)))
        .write(
      db.CollectionCallBatchesCompanion(
        status: Value(
          failed ? CallBatchStatus.failed : CallBatchStatus.completed,
        ),
        updatedAt: Value(now),
      ),
    );
  }
}
