import 'package:daftar/data/datasources/local/drift_database.dart' as db;
import 'package:daftar/data/mappers/audit_log_mapper.dart';
import 'package:daftar/data/models/audit_log_model.dart';
import 'package:drift/drift.dart' as drift;

/// Local data source for audit log persistence.
class AuditLogLocalDataSource {
  /// Creates an audit log local data source.
  AuditLogLocalDataSource(this.database);

  /// Drift database dependency.
  final db.AppDatabase database;

  /// Appends an audit log entry.
  Future<AuditLogModel> appendLog(AuditLogModel log) async {
    await database.into(database.auditLogs).insert(log.toDrift());
    return log;
  }

  Future<void> bulkAppendAuditLogs(List<AuditLogModel> logs) async {
    if (logs.isEmpty) {
      return;
    }

    await database.batch((batch) {
      batch.insertAll(
        database.auditLogs,
        logs.map((log) => log.toDrift()).toList(growable: false),
      );
    });
  }

  /// Returns audit logs for a specific entity.
  Future<List<AuditLogModel>> getLogsByEntity(
    String entityType,
    String entityId,
  ) async {
    final rows =
        await (database.select(database.auditLogs)
              ..where((table) => table.entityType.equals(entityType))
              ..where((table) => table.entityId.equals(entityId))
              ..orderBy([
                (table) => drift.OrderingTerm(
                  expression: table.timestamp,
                  mode: drift.OrderingMode.desc,
                ),
              ]))
            .get();

    return rows.map((row) => row.toModel()).toList(growable: false);
  }

  /// Returns audit logs not yet acknowledged by the server push path.
  ///
  /// Ordered by `audit_logs.timestamp` ascending, then `audit_logs.id` for
  /// stable replay. Only includes syncable entity types.
  Future<List<AuditLogModel>> getPendingPushLogs({int limit = 500}) async {
    final rows =
        await (database.select(database.auditLogs)
              ..where(
                (table) =>
                    table.entityType.isIn(_syncableTypes) &
                    _isNotAcked(table),
              )
              ..orderBy([
                (table) => drift.OrderingTerm(expression: table.timestamp),
                (table) => drift.OrderingTerm(expression: table.id),
              ])
              ..limit(limit))
            .get();

    return rows.map((row) => row.toModel()).toList(growable: false);
  }

  /// Count of local audit logs not yet pushed to the server.
  Future<int> countPendingPushLogs() async {
    final countExpr = database.auditLogs.id.count();
    final query = database.selectOnly(database.auditLogs)
      ..addColumns([countExpr])
      ..where(
        database.auditLogs.entityType.isIn(_syncableTypes) &
            _isNotAcked(database.auditLogs),
      );
    final row = await query.getSingle();
    return row.read(countExpr) ?? 0;
  }

  static const List<String> _syncableTypes = [
    'ledger',
    'contact',
    'transaction',
  ];

  /// Excludes acknowledged rows in SQL.
  ///
  /// Filtering in Dart after a LIMIT silently stops the push queue once the
  /// device accumulates more than `limit` lifetime audit rows: the page fills
  /// entirely with already-acked history and every new mutation starves.
  drift.Expression<bool> _isNotAcked(db.$AuditLogsTable table) {
    return drift.notExistsQuery(
      database.selectOnly(database.syncOutboundAcks)
        ..addColumns([database.syncOutboundAcks.auditLogId])
        ..where(
          database.syncOutboundAcks.auditLogId.equalsExp(table.id),
        ),
    );
  }

  /// Returns the most recent audit logs.
  Future<List<AuditLogModel>> getRecentLogs(int limit) async {
    final rows =
        await (database.select(database.auditLogs)
              ..orderBy([
                (table) => drift.OrderingTerm(
                  expression: table.timestamp,
                  mode: drift.OrderingMode.desc,
                ),
              ])
              ..limit(limit))
            .get();

    return rows.map((row) => row.toModel()).toList(growable: false);
  }

  /// Returns the total number of local audit-log rows (pending push upper bound).
  ///
  /// Stage 8.4 will subtract the pushed watermark; until then this is the
  /// honest local mutation count.
  Future<int> countAllLogs() async {
    final countExpr = database.auditLogs.id.count();
    final query = database.selectOnly(database.auditLogs)
      ..addColumns([countExpr]);
    final row = await query.getSingle();
    return row.read(countExpr) ?? 0;
  }

  /// Returns audit logs since [since] (inclusive), newest first.
  Future<List<AuditLogModel>> getLogsSince(DateTime since, {int limit = 1000}) async {
    final rows =
        await (database.select(database.auditLogs)
              ..where((table) => table.timestamp.isBiggerOrEqualValue(since))
              ..orderBy([
                (table) => drift.OrderingTerm(
                  expression: table.timestamp,
                  mode: drift.OrderingMode.desc,
                ),
              ])
              ..limit(limit))
            .get();

    return rows.map((row) => row.toModel()).toList(growable: false);
  }
}
