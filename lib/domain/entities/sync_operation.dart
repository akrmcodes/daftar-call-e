import 'package:freezed_annotation/freezed_annotation.dart';

part 'sync_operation.freezed.dart';

/// A single sync operation from the server op-log.
///
/// Represents a CREATE, UPDATE, or DELETE mutation that was performed
/// on a remote device and needs to be applied locally. The server assigns
/// [opSeq] and [serverUpdatedAt] — clients order by these values,
/// never by device clocks (clock-skew safe).
///
/// Fields:
/// - [id]: UUID v4 — the operation's unique identifier (same as the AuditLog id on the originating device).
/// - [entityType]: Type of entity modified ('ledger', 'contact', 'transaction').
/// - [entityId]: UUID of the target entity.
/// - [action]: The mutation type ('CREATE', 'UPDATE', 'DELETE').
/// - [fieldDeltas]: JSON map of changed fields → new values. Only present for UPDATE ops.
/// - [deviceId]: Identifier of the device that originated this operation.
/// - [role]: Workspace role of the user who performed the op ('owner', 'editor').
/// - [localTimestamp]: The device-local UTC timestamp when the op was created.
/// - [serverUpdatedAt]: Server-assigned UTC timestamp (ordering authority).
/// - [opSeq]: Server-assigned monotonic sequence number (global order).
@freezed
abstract class SyncOperation with _$SyncOperation {
  const factory SyncOperation({
    required String id,
    required String entityType,
    required String entityId,
    required String action,
    required String deviceId,
    required String role,
    required DateTime localTimestamp,
    required DateTime serverUpdatedAt,
    required int opSeq,
    String? fieldDeltas,
  }) = _SyncOperation;
}
