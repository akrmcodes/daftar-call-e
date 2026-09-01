import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/repositories/collections_send_queue_repository.dart';
import 'package:daftar/domain/value_objects/collections_send_queue.dart';
import 'package:fpdart/fpdart.dart';

/// Persists the in-flight Hybrid E send queue.
class SaveCollectionsSendQueueUseCase {
  /// Creates the use case.
  const SaveCollectionsSendQueueUseCase(this._repository);

  final CollectionsSendQueueRepository _repository;

  /// Upserts [queue].
  Future<Either<Failure, Unit>> execute(CollectionsSendQueue queue) {
    return _repository.upsert(queue);
  }
}

/// Loads leftover Hybrid E in-flight (`batchId` null). SMTP queues are ignored.
class LoadInFlightCollectionsSendQueueUseCase {
  /// Creates the use case.
  const LoadInFlightCollectionsSendQueueUseCase(this._repository);

  final CollectionsSendQueueRepository _repository;

  /// Returns null when nothing is in flight.
  Future<Either<Failure, CollectionsSendQueue?>> execute() {
    return _repository.getInFlight();
  }
}

/// Marks a Hybrid E send queue completed.
class CompleteCollectionsSendQueueUseCase {
  /// Creates the use case.
  const CompleteCollectionsSendQueueUseCase(this._repository);

  final CollectionsSendQueueRepository _repository;

  /// Completes [queueId].
  Future<Either<Failure, Unit>> execute(String queueId) {
    return _repository.complete(queueId);
  }
}
