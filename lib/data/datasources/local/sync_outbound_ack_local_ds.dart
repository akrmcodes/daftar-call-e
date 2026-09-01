import 'dart:convert';

import 'package:daftar/core/utils/uuid_util.dart';
import 'package:daftar/data/datasources/local/drift_database.dart' as db;
import 'package:daftar/data/models/merge_conflict_model.dart';
import 'package:daftar/domain/enums/conflict_type.dart';
import 'package:drift/drift.dart' as drift;

/// A push op the server refused, with the local context needed to explain it.
typedef PushRejectionRecord = ({
  String auditLogId,
  String code,
  String entityType,
  String entityId,
  String? payload,
});

/// Local persistence for outbound push settlement (acks and rejections).
class SyncOutboundAckLocalDs {
  /// Creates the data source.
  SyncOutboundAckLocalDs(this._database);

  final db.AppDatabase _database;

  /// Records server acknowledgment for a pushed audit log row.
  Future<void> recordAcks(
    List<({
      String auditLogId,
      int opSeq,
      DateTime serverUpdatedAt,
    })> acks,
  ) async {
    if (acks.isEmpty) {
      return;
    }

    final now = DateTime.now().toUtc();
    await _database.batch((batch) {
      batch.insertAll(
        _database.syncOutboundAcks,
        acks
            .map(
              (ack) => db.SyncOutboundAcksCompanion.insert(
                auditLogId: ack.auditLogId,
                opSeq: ack.opSeq,
                serverUpdatedAt: ack.serverUpdatedAt,
                ackedAt: drift.Value(now),
              ),
            )
            .toList(growable: false),
        mode: drift.InsertMode.insertOrReplace,
      );
    });
  }

  /// Quarantines ops the server refused and surfaces them for review.
  ///
  /// A rejected op is settled, not pending: leaving it in the push queue
  /// wedges outbound sync forever behind an op the server will never accept.
  /// The matching conflict row is what makes the loss visible instead of
  /// silent — the mutation exists locally and will never reach the server.
  ///
  /// Both writes land in one transaction so an op can never be silenced
  /// without also being surfaced.
  Future<void> recordRejections(List<PushRejectionRecord> rejections) async {
    if (rejections.isEmpty) {
      return;
    }

    final now = DateTime.now().toUtc();
    await _database.transaction(() async {
      await _database.batch((batch) {
        batch
          ..insertAll(
            _database.syncOutboundAcks,
            rejections
                .map(
                  (rejection) => db.SyncOutboundAcksCompanion.insert(
                    auditLogId: rejection.auditLogId,
                    opSeq: 0,
                    serverUpdatedAt: now,
                    ackedAt: drift.Value(now),
                    rejectionCode: drift.Value(rejection.code),
                  ),
                )
                .toList(growable: false),
            mode: drift.InsertMode.insertOrReplace,
          )
          ..insertAll(
            _database.mergeConflicts,
            rejections
                .map(
                  (rejection) => MergeConflictModel(
                    id: UuidUtil.generate(),
                    entityType: rejection.entityType,
                    entityId: rejection.entityId,
                    conflictType: ConflictType.rejectedByServer,
                    localSnapshot: rejection.payload ?? '{}',
                    remoteSnapshot: jsonEncode(<String, String>{
                      'rejected_op': rejection.auditLogId,
                      'code': rejection.code,
                    }),
                    detectedAt: now,
                  ).toCompanion(),
                )
                .toList(growable: false),
            mode: drift.InsertMode.insertOrReplace,
          );
      });
    });
  }

  /// Returns audit log ids the server has settled (accepted or refused).
  Future<Set<String>> getAckedAuditLogIds() async {
    final rows = await _database.select(_database.syncOutboundAcks).get();
    return rows.map((row) => row.auditLogId).toSet();
  }
}
