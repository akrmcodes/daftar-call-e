import 'package:daftar/domain/enums/call_batch_status.dart';
import 'package:daftar/domain/enums/call_batch_trigger.dart';
import 'package:drift/drift.dart';

/// Confirm & Call batch header (device SoT; mirrors J.9 batchId).
@TableIndex(name: 'idx_collection_call_batches_batch_id', columns: {#batchId}, unique: true)
@TableIndex(name: 'idx_collection_call_batches_status', columns: {#status})
@TableIndex(name: 'idx_collection_call_batches_created_at', columns: {#createdAt})
class CollectionCallBatches extends Table {
  /// UUID v4 primary key.
  TextColumn get id => text()();

  /// Device-generated J.9 batch UUID.
  TextColumn get batchId => text()();

  /// J.9 correlation UUID.
  TextColumn get correlationId => text()();

  /// `closeDay` or `creditLimit`.
  TextColumn get trigger => textEnum<CallBatchTrigger>()();

  /// Batch lifecycle on device.
  TextColumn get status => textEnum<CallBatchStatus>()();

  /// UTC insert time.
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// UTC last mutation.
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  /// Soft-delete flag.
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  /// Sync conflict resolution version.
  IntColumn get syncVersion => integer().withDefault(const Constant(0))();

  @override
  String get tableName => 'collection_call_batches';

  @override
  Set<Column<Object>> get primaryKey => {id};
}
