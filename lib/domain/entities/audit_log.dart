import 'package:freezed_annotation/freezed_annotation.dart';

part 'audit_log.freezed.dart';

/// Immutable record of a data modification event for audit trail purposes.
///
/// Every CREATE, UPDATE, and DELETE operation on core entities (ledgers,
/// contacts, transactions) appends an [AuditLog] entry. The audit log
/// is append-only — entries are never modified or deleted.
///
/// The audit log serves multiple purposes:
/// 1. Data integrity verification
/// 2. Sync conflict resolution (operation replay)
/// 3. User activity history
///
/// Fields:
/// - [id]: UUID v4 primary key.
/// - [entityType]: Type of entity modified (e.g., 'ledger', 'contact', 'transaction').
/// - [entityId]: UUID of the modified entity.
/// - [action]: The operation performed ('CREATE', 'UPDATE', 'DELETE').
/// - [payload]: Optional JSON string containing the changed fields/values.
/// - [timestamp]: UTC timestamp of the operation.
/// - [deviceId]: Identifier for the device that performed the operation.
///   Used for multi-device sync conflict resolution.
@freezed
abstract class AuditLog with _$AuditLog {
  const factory AuditLog({
    required String id,
    required String entityType,
    required String entityId,
    required String action,
    required DateTime timestamp, required String deviceId, String? payload,
  }) = _AuditLog;
}
