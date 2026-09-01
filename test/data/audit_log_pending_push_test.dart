import 'package:daftar/data/datasources/local/audit_log_local_ds.dart';
import 'package:daftar/data/datasources/local/drift_database.dart';
import 'package:daftar/data/datasources/local/sync_outbound_ack_local_ds.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// The pending-push queue is the only path local mutations take to other
/// devices. If it silently returns nothing, the merchant's phone keeps
/// recording debts that no other device will ever see.
void main() {
  late AppDatabase db;
  late AuditLogLocalDataSource sut;
  late SyncOutboundAckLocalDs ackDs;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    sut = AuditLogLocalDataSource(db);
    ackDs = SyncOutboundAckLocalDs(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> seedLogs({
    required int count,
    required String prefix,
    required DateTime from,
  }) async {
    await db.batch((batch) {
      batch.insertAll(
        db.auditLogs,
        List.generate(
          count,
          (i) => AuditLogsCompanion.insert(
            id: '$prefix-${i.toString().padLeft(5, '0')}',
            entityType: 'transaction',
            entityId: 'txn-$prefix-$i',
            action: 'CREATE',
            deviceId: 'device-1',
            timestamp: Value(from.add(Duration(seconds: i))),
          ),
        ),
      );
    });
  }

  Future<void> ackAll(List<String> ids) async {
    await ackDs.recordAcks(
      ids
          .map(
            (id) => (
              auditLogId: id,
              opSeq: 1,
              serverUpdatedAt: DateTime.utc(2026),
            ),
          )
          .toList(growable: false),
    );
  }

  group('AuditLogLocalDataSource.getPendingPushLogs', () {
    test('returns unacked logs that sit past the page window', () async {
      // Filtering acked ids in Dart *after* a LIMIT means the page fills with
      // old acked history and the queue looks permanently empty.
      await seedLogs(count: 520, prefix: 'old', from: DateTime.utc(2026));
      final oldIds = (await db.select(db.auditLogs).get())
          .map((row) => row.id)
          .toList(growable: false);
      await ackAll(oldIds);

      await seedLogs(
        count: 3,
        prefix: 'new',
        from: DateTime.utc(2026, 1, 2),
      );

      final pending = await sut.getPendingPushLogs();

      expect(pending, hasLength(3));
      expect(
        pending.map((log) => log.id),
        everyElement(startsWith('new-')),
      );
    });

    test('countPendingPushLogs matches the queue contents', () async {
      await seedLogs(count: 10, prefix: 'a', from: DateTime.utc(2026));
      final ids = (await db.select(db.auditLogs).get())
          .map((row) => row.id)
          .take(4)
          .toList(growable: false);
      await ackAll(ids);

      expect(await sut.countPendingPushLogs(), 6);
      expect(await sut.getPendingPushLogs(), hasLength(6));
    });

    test('non-syncable entity types never enter the push queue', () async {
      await db.into(db.auditLogs).insert(
            AuditLogsCompanion.insert(
              id: 'log-activation',
              entityType: 'activation',
              entityId: 'act-1',
              action: 'LINKED',
              deviceId: 'device-1',
            ),
          );

      expect(await sut.getPendingPushLogs(), isEmpty);
      expect(await sut.countPendingPushLogs(), 0);
    });

    test('the queue is ordered oldest-first for stable replay', () async {
      await seedLogs(count: 5, prefix: 'z', from: DateTime.utc(2026, 1, 5));
      await seedLogs(count: 5, prefix: 'a', from: DateTime.utc(2026));

      final pending = await sut.getPendingPushLogs();
      final timestamps = pending.map((log) => log.timestamp).toList();

      expect(pending, hasLength(10));
      for (var i = 1; i < timestamps.length; i++) {
        expect(
          timestamps[i].isBefore(timestamps[i - 1]),
          isFalse,
          reason: 'Replay order must be non-decreasing in time',
        );
      }
    });
  });
}
