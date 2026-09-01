import 'package:drift/drift.dart';

/// Tracks server settlement of locally pushed audit-log operations.
///
/// Local audit log rows stay immutable; push progress is recorded here
/// so pending-push queries exclude already-settled ops. A row means the
/// server has made a final decision about the op — accepted (with an
/// [opSeq]) or rejected (with a [rejectionCode]). Either way it must never
/// be pushed again: a rejected op that stays queued blocks every later
/// mutation on this device behind it.
@TableIndex(
  name: 'idx_sync_outbound_acks_op_seq',
  columns: {#opSeq},
)
class SyncOutboundAcks extends Table {
  /// FK to the local audit log row that was pushed.
  TextColumn get auditLogId => text()();

  /// Server-assigned monotonic sequence for the accepted op.
  ///
  /// Zero for rejected ops — the server assigned them no sequence.
  IntColumn get opSeq => integer()();

  /// Server-assigned ordering timestamp.
  DateTimeColumn get serverUpdatedAt => dateTime()();

  /// Machine-readable rejection code when the server refused this op.
  ///
  /// Null for accepted ops.
  TextColumn get rejectionCode => text().nullable()();

  /// When this device recorded the push acknowledgment.
  DateTimeColumn get ackedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {auditLogId};
}
