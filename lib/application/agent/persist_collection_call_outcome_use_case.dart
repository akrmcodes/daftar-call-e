import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/repositories/collection_call_repository.dart';
import 'package:daftar/domain/value_objects/collection_call_persist.dart';
import 'package:fpdart/fpdart.dart';

/// Persists CALL-E `runId` and integer promises. Never writes a ledger txn.
class PersistCollectionCallOutcomeUseCase {
  /// Creates the use case.
  const PersistCollectionCallOutcomeUseCase({
    required CollectionCallRepository collectionCallRepository,
  }) : _collectionCallRepository = collectionCallRepository;

  final CollectionCallRepository _collectionCallRepository;

  /// Writes queued `runId` rows after `run-batch`.
  Future<Either<Failure, Unit>> persistQueued(
    CollectionCallBatchSeed seed,
  ) {
    return _collectionCallRepository.persistQueuedBatch(seed);
  }

  /// Writes a terminal GET. Upserts `collection_promises` only for a valid int.
  Future<Either<Failure, Unit>> persistTerminal(
    CollectionCallTerminalWrite write,
  ) {
    return _collectionCallRepository.persistTerminalWrite(write);
  }
}
