import 'package:daftar/data/datasources/local/collections_send_queue_local_ds.dart';
import 'package:daftar/data/datasources/local/drift_database.dart';
import 'package:daftar/data/repositories/collections_send_queue_repository_impl.dart';
import 'package:daftar/domain/enums/closing_backup_status.dart';
import 'package:daftar/domain/enums/closing_pdf_policy.dart';
import 'package:daftar/domain/enums/closing_reminder_policy.dart';
import 'package:daftar/domain/enums/collections_desk_row_status.dart';
import 'package:daftar/domain/enums/collections_send_queue_status.dart';
import 'package:daftar/domain/enums/reminder_tone_band.dart';
import 'package:daftar/domain/value_objects/closing_day_summary.dart';
import 'package:daftar/domain/value_objects/closing_ritual_result.dart';
import 'package:daftar/domain/value_objects/collections_candidate.dart';
import 'package:daftar/domain/value_objects/collections_desk_row.dart';
import 'package:daftar/domain/value_objects/collections_send_queue.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late CollectionsSendQueueRepositoryImpl repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = CollectionsSendQueueRepositoryImpl(
      collectionsSendQueueLocalDataSource: CollectionsSendQueueLocalDataSource(
        database,
      ),
    );
  });

  tearDown(() async {
    await database.close();
  });

  CollectionsCandidate candidate(String id) {
    return CollectionsCandidate(
      contactId: id,
      name: 'n$id',
      phone: '+96770000000$id',
      ledgerId: 'ledger',
      netBalance: -1500,
      currencyCode: 'YER',
      ageDays: 40,
      toneBand: ReminderToneBand.firm,
    );
  }

  CollectionsSendQueue queue({
    required String id,
    required CollectionsSendQueueStatus status,
    required bool awaitingResume,
    required List<CollectionsDeskRow> rows,
    String? batchId,
  }) {
    final now = DateTime.utc(2026, 8, 15, 20);
    return CollectionsSendQueue(
      id: id,
      status: status,
      awaitingResume: awaitingResume,
      locale: 'ar',
      storeName: 'Daftar',
      ritual: ClosingRitualResult(
        summary: const ClosingDaySummary(
          localDay: '2026-08-15',
          debtCount: 2,
          paymentCount: 1,
          totals: [
            ClosingDayCurrencyTotals(
              currencyCode: 'YER',
              debtMinor: 1500,
              paymentMinor: 200,
            ),
          ],
        ),
        backupStatus: ClosingBackupStatus.uploaded,
        shortlist: [candidate('a'), candidate('b')],
        reminderPolicy: ClosingReminderPolicy.top5,
        pdfPolicy: ClosingPdfPolicy.selective,
        overdueTotal: 9,
      ),
      rows: rows,
      createdAt: now,
      updatedAt: now,
      batchId: batchId,
    );
  }

  test('upsert then getInFlight round-trips integer money and Top 5', () async {
    final saved = queue(
      id: 'q-1',
      status: CollectionsSendQueueStatus.active,
      awaitingResume: true,
      rows: [
        CollectionsDeskRow(
          candidate: candidate('a'),
          body: 'draft-a',
          toneBand: ReminderToneBand.friendly,
          attachPdf: true,
          status: CollectionsDeskRowStatus.opened,
        ),
        CollectionsDeskRow(
          candidate: candidate('b'),
          body: 'draft-b',
          toneBand: ReminderToneBand.firm,
          attachPdf: false,
        ),
      ],
    );

    final upserted = await repository.upsert(saved);
    expect(upserted.isRight(), isTrue);

    final loaded = await repository.getInFlight();
    final restored = loaded.getRight().toNullable();
    expect(restored, isNotNull);
    expect(restored!.id, 'q-1');
    expect(restored.status, CollectionsSendQueueStatus.active);
    expect(restored.awaitingResume, isTrue);
    expect(restored.locale, 'ar');
    expect(restored.ritual.reminderPolicy, ClosingReminderPolicy.top5);
    expect(restored.ritual.overdueCount, 9);
    expect(restored.ritual.summary.totals.single.debtMinor, 1500);
    expect(restored.rows, hasLength(2));
    expect(restored.rows.first.status, CollectionsDeskRowStatus.opened);
    expect(restored.rows.first.attachPdf, isTrue);
    expect(restored.rows.first.body, 'draft-a');
    expect(restored.rows.last.status, CollectionsDeskRowStatus.pending);
    expect(restored.rows.first.candidate.netBalance, -1500);
  });

  test('complete removes the queue from getInFlight', () async {
    final saved = queue(
      id: 'q-2',
      status: CollectionsSendQueueStatus.paused,
      awaitingResume: false,
      rows: [
        CollectionsDeskRow(
          candidate: candidate('a'),
          body: 'draft-a',
          toneBand: ReminderToneBand.reminder,
          attachPdf: false,
        ),
      ],
    );
    await repository.upsert(saved);
    final completed = await repository.complete('q-2');
    expect(completed.isRight(), isTrue);
    final loaded = await repository.getInFlight();
    expect(loaded.getRight().toNullable(), isNull);
  });

  test('upsert completes any other in-flight queue', () async {
    await repository.upsert(
      queue(
        id: 'old',
        status: CollectionsSendQueueStatus.active,
        awaitingResume: false,
        rows: [
          CollectionsDeskRow(
            candidate: candidate('a'),
            body: 'old',
            toneBand: ReminderToneBand.reminder,
            attachPdf: false,
          ),
        ],
      ),
    );
    await repository.upsert(
      queue(
        id: 'new',
        status: CollectionsSendQueueStatus.active,
        awaitingResume: false,
        rows: [
          CollectionsDeskRow(
            candidate: candidate('b'),
            body: 'new',
            toneBand: ReminderToneBand.reminder,
            attachPdf: false,
          ),
        ],
      ),
    );
    final loaded = await repository.getInFlight();
    expect(loaded.getRight().toNullable()?.id, 'new');
  });

  test('getInFlight ignores SMTP active queues with batchId', () async {
    await repository.upsert(
      queue(
        id: 'smtp',
        status: CollectionsSendQueueStatus.active,
        awaitingResume: false,
        batchId: '11111111-1111-4111-8111-111111111111',
        rows: [
          CollectionsDeskRow(
            candidate: candidate('a'),
            body: 'smtp',
            toneBand: ReminderToneBand.reminder,
            attachPdf: true,
          ),
        ],
      ),
    );
    final loaded = await repository.getInFlight();
    expect(loaded.getRight().toNullable(), isNull);
  });

  test('getInFlight still loads Hybrid E active queue with null batchId', () async {
    await repository.upsert(
      queue(
        id: 'hybrid',
        status: CollectionsSendQueueStatus.active,
        awaitingResume: false,
        rows: [
          CollectionsDeskRow(
            candidate: candidate('a'),
            body: 'hybrid',
            toneBand: ReminderToneBand.reminder,
            attachPdf: false,
          ),
        ],
      ),
    );
    final loaded = await repository.getInFlight();
    expect(loaded.getRight().toNullable()?.id, 'hybrid');
    expect(loaded.getRight().toNullable()?.batchId, isNull);
  });
}
