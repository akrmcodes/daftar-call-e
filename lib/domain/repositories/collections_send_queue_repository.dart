import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/value_objects/collections_send_queue.dart';
import 'package:fpdart/fpdart.dart';

/// Persistence for the leftover Hybrid E WhatsApp send queue.
abstract class CollectionsSendQueueRepository {
  /// Leftover Hybrid E only: latest `active`/`paused` row with null `batchId`.
  ///
  /// SMTP queues (`batchId` set) are never in-flight for the sticky bar.
  Future<Either<Failure, CollectionsSendQueue?>> getInFlight();

  /// Inserts or replaces [queue] (and its items) atomically.
  ///
  /// Any other in-flight queue is marked completed so only one Sending i of N
  /// exists.
  Future<Either<Failure, Unit>> upsert(CollectionsSendQueue queue);

  /// Marks [queueId] completed. No-op when the row is missing.
  Future<Either<Failure, Unit>> complete(String queueId);
}
