import 'package:daftar/core/services/device_identity_store.dart';
import 'package:daftar/core/services/sync_token_store.dart';
import 'package:daftar/data/datasources/local/audit_log_local_ds.dart';
import 'package:daftar/data/datasources/local/drift_database.dart';
import 'package:daftar/data/datasources/local/merge_engine_local_ds.dart';
import 'package:daftar/data/datasources/local/sync_outbound_ack_local_ds.dart';
import 'package:daftar/data/models/audit_log_model.dart';
import 'package:daftar/data/repositories/merge_engine_repository_impl.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('pending push ops', () {
    late AppDatabase database;
    late AuditLogLocalDataSource auditDs;
    late SyncOutboundAckLocalDs ackDs;
    late MergeEngineRepositoryImpl repository;

    setUp(() async {
      DeviceIdentity.initializeForTest('device-test');
      database = AppDatabase(NativeDatabase.memory());
      auditDs = AuditLogLocalDataSource(database);
      ackDs = SyncOutboundAckLocalDs(database);
      repository = MergeEngineRepositoryImpl(
        mergeEngineDs: MergeEngineLocalDs(database),
        auditLogDs: auditDs,
        syncTokenStore: SyncTokenStore(),
      );
    });

    tearDown(() async {
      await database.close();
    });

    test('excludes acked audit logs from pending ops', () async {
      await auditDs.appendLog(
        AuditLogModel(
          id: 'op-1',
          entityType: 'ledger',
          entityId: 'ledger-1',
          action: 'CREATE',
          timestamp: DateTime.utc(2026),
          deviceId: 'device-test',
        ),
      );
      await auditDs.appendLog(
        AuditLogModel(
          id: 'op-2',
          entityType: 'contact',
          entityId: 'contact-1',
          action: 'CREATE',
          timestamp: DateTime.utc(2026, 1, 2),
          deviceId: 'device-test',
        ),
      );

      await ackDs.recordAcks([
        (
          auditLogId: 'op-1',
          opSeq: 10,
          serverUpdatedAt: DateTime.utc(2026, 1, 1, 1),
        ),
      ]);

      final pending = await repository.getPendingLocalOps();
      pending.fold(
        (_) => fail('unexpected failure'),
        (ops) {
          expect(ops.length, 1);
          expect(ops.single.id, 'op-2');
        },
      );

      expect(await auditDs.countPendingPushLogs(), 1);
    });
  });
}
