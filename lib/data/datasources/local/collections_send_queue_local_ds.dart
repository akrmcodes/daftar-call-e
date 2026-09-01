import 'dart:convert';

import 'package:daftar/core/utils/uuid_util.dart';
import 'package:daftar/data/datasources/local/drift_database.dart' as db;
import 'package:daftar/domain/enums/closing_backup_status.dart';
import 'package:daftar/domain/enums/closing_pdf_policy.dart';
import 'package:daftar/domain/enums/closing_reminder_policy.dart';
import 'package:daftar/domain/enums/collections_send_queue_status.dart';
import 'package:daftar/domain/enums/reminder_tone_band.dart';
import 'package:daftar/domain/value_objects/closing_day_summary.dart';
import 'package:daftar/domain/value_objects/closing_ritual_result.dart';
import 'package:daftar/domain/value_objects/collections_candidate.dart';
import 'package:daftar/domain/value_objects/collections_desk_row.dart';
import 'package:daftar/domain/value_objects/collections_send_queue.dart';
import 'package:drift/drift.dart';

/// Local persistence for the Hybrid E Collections send queue.
class CollectionsSendQueueLocalDataSource {
  /// Creates the data source.
  CollectionsSendQueueLocalDataSource(this.database);

  /// Drift database.
  final db.AppDatabase database;

  /// Latest leftover Hybrid E queue (`active`/`paused` and `batchId IS NULL`).
  ///
  /// SMTP headers (`batchId` set) must not restore Sending i of N.
  Future<CollectionsSendQueue?> getInFlight() async {
    final header =
        await (database.select(database.collectionsSendQueueHeaders)
              ..where(
                (table) =>
                    table.status.isIn([
                      CollectionsSendQueueStatus.active.name,
                      CollectionsSendQueueStatus.paused.name,
                    ]) &
                    table.batchId.isNull(),
              )
              ..orderBy([
                (table) => OrderingTerm(
                  expression: table.updatedAt,
                  mode: OrderingMode.desc,
                ),
              ])
              ..limit(1))
            .getSingleOrNull();
    if (header == null) {
      return null;
    }
    final items =
        await (database.select(database.collectionsSendQueueItemRows)
              ..where((table) => table.queueId.equals(header.id))
              ..orderBy([
                (table) => OrderingTerm(expression: table.sortOrder),
              ]))
            .get();
    return _toDomain(header, items);
  }

  /// Replaces [queue] items and marks any other in-flight queue completed.
  Future<void> upsert(CollectionsSendQueue queue) async {
    final now = DateTime.now().toUtc();
    await database.transaction(() async {
      final others =
          await (database.select(database.collectionsSendQueueHeaders)..where(
                (table) =>
                    table.status.isIn([
                      CollectionsSendQueueStatus.active.name,
                      CollectionsSendQueueStatus.paused.name,
                    ]) &
                    table.id.isNotValue(queue.id),
              ))
              .get();
      for (final other in others) {
        await (database.update(
          database.collectionsSendQueueHeaders,
        )..where((table) => table.id.equals(other.id))).write(
          db.CollectionsSendQueueHeadersCompanion(
            status: const Value(CollectionsSendQueueStatus.completed),
            awaitingResume: const Value(false),
            updatedAt: Value(now),
          ),
        );
      }

      await (database.delete(
        database.collectionsSendQueueItemRows,
      )..where((table) => table.queueId.equals(queue.id))).go();

      await database
          .into(database.collectionsSendQueueHeaders)
          .insertOnConflictUpdate(_headerCompanion(queue, now));

      var sort = 0;
      for (final row in queue.rows) {
        await database
            .into(database.collectionsSendQueueItemRows)
            .insert(_itemCompanion(queue.id, sort, row, now));
        sort += 1;
      }
    });
  }

  /// Marks [queueId] completed.
  Future<void> complete(String queueId) async {
    await (database.update(
      database.collectionsSendQueueHeaders,
    )..where((table) => table.id.equals(queueId))).write(
      db.CollectionsSendQueueHeadersCompanion(
        status: const Value(CollectionsSendQueueStatus.completed),
        awaitingResume: const Value(false),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  db.CollectionsSendQueueHeadersCompanion _headerCompanion(
    CollectionsSendQueue queue,
    DateTime now,
  ) {
    final summary = queue.ritual.summary;
    return db.CollectionsSendQueueHeadersCompanion(
      id: Value(queue.id),
      status: Value(queue.status),
      awaitingResume: Value(queue.awaitingResume),
      locale: Value(queue.locale),
      storeName: Value(queue.storeName),
      localDay: Value(summary.localDay),
      backupStatus: Value(queue.ritual.backupStatus.name),
      batchId: Value(queue.batchId),
      reminderPolicy: Value(queue.ritual.reminderPolicy.name),
      pdfPolicy: Value(queue.ritual.pdfPolicy.name),
      needsHuman: Value(queue.ritual.needsHuman),
      overdueTotal: Value(queue.ritual.overdueCount),
      debtCount: Value(summary.debtCount),
      paymentCount: Value(summary.paymentCount),
      totalsJson: Value(_encodeTotals(summary.totals)),
      createdAt: Value(queue.createdAt.toUtc()),
      updatedAt: Value(now),
    );
  }

  db.CollectionsSendQueueItemRowsCompanion _itemCompanion(
    String queueId,
    int sortOrder,
    CollectionsDeskRow row,
    DateTime now,
  ) {
    final candidate = row.candidate;
    return db.CollectionsSendQueueItemRowsCompanion.insert(
      id: UuidUtil.generate(),
      queueId: queueId,
      sortOrder: sortOrder,
      contactId: candidate.contactId,
      name: candidate.name,
      phone: candidate.phone ?? '',
      email: Value(candidate.email),
      ledgerId: candidate.ledgerId,
      netBalance: candidate.netBalance,
      currencyCode: candidate.currencyCode,
      ageDays: candidate.ageDays,
      toneBand: row.toneBand.name,
      body: row.body,
      subject: Value(row.subject),
      attachPdf: Value(row.attachPdf),
      status: row.status,
      smtpMessageId: Value(row.smtpMessageId),
      smtpCode: Value(row.smtpCode),
      createdAt: Value(now),
      updatedAt: Value(now),
    );
  }

  CollectionsSendQueue _toDomain(
    db.CollectionsSendQueueHeader header,
    List<db.CollectionsSendQueueItemRow> items,
  ) {
    final rows = [
      for (final item in items)
        CollectionsDeskRow(
          candidate: CollectionsCandidate(
            contactId: item.contactId,
            name: item.name,
            phone: item.phone.isEmpty ? null : item.phone,
            email: item.email,
            ledgerId: item.ledgerId,
            netBalance: item.netBalance,
            currencyCode: item.currencyCode,
            ageDays: item.ageDays,
            toneBand: _tone(item.toneBand),
          ),
          subject: item.subject,
          body: item.body,
          toneBand: _tone(item.toneBand),
          attachPdf: item.attachPdf,
          status: item.status,
          smtpMessageId: item.smtpMessageId,
          smtpCode: item.smtpCode,
        ),
    ];
    final reconstructed = [
      for (final row in rows) row.candidate,
    ];
    return CollectionsSendQueue(
      id: header.id,
      status: header.status,
      awaitingResume: header.awaitingResume,
      locale: header.locale,
      storeName: header.storeName,
      ritual: ClosingRitualResult(
        summary: ClosingDaySummary(
          localDay: header.localDay,
          debtCount: header.debtCount,
          paymentCount: header.paymentCount,
          totals: _decodeTotals(header.totalsJson),
        ),
        backupStatus: ClosingBackupStatus.values.byName(header.backupStatus),
        shortlist: reconstructed,
        reminderPolicy: ClosingReminderPolicy.values.byName(
          header.reminderPolicy,
        ),
        pdfPolicy: ClosingPdfPolicy.values.byName(header.pdfPolicy),
        needsHuman: header.needsHuman,
        overdueTotal: header.overdueTotal,
      ),
      rows: rows,
      createdAt: header.createdAt.toUtc(),
      updatedAt: header.updatedAt.toUtc(),
      batchId: header.batchId,
    );
  }

  ReminderToneBand _tone(String raw) {
    return ReminderToneBand.values.byName(raw);
  }

  String _encodeTotals(List<ClosingDayCurrencyTotals> totals) {
    return jsonEncode([
      for (final row in totals)
        <String, Object>{
          'currencyCode': row.currencyCode,
          'debtMinor': row.debtMinor,
          'paymentMinor': row.paymentMinor,
        },
    ]);
  }

  List<ClosingDayCurrencyTotals> _decodeTotals(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! List<dynamic>) {
      return const [];
    }
    return [
      for (final item in decoded)
        if (item is Map)
          ClosingDayCurrencyTotals(
            currencyCode: item['currencyCode'] as String? ?? '',
            debtMinor: item['debtMinor'] is int ? item['debtMinor'] as int : 0,
            paymentMinor: item['paymentMinor'] is int
                ? item['paymentMinor'] as int
                : 0,
          ),
    ];
  }
}
