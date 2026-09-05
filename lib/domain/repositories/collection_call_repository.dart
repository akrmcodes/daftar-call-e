import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/value_objects/collection_call_persist.dart';
import 'package:fpdart/fpdart.dart';

/// Drift persistence for Confirm & Call runs and display-only promises.
abstract class CollectionCallRepository {
  /// Inserts the batch header and queued run rows (with `runId`) atomically.
  Future<Either<Failure, Unit>> persistQueuedBatch(CollectionCallBatchSeed seed);

  /// Updates a run from a terminal GET. Upserts a promise when valid.
  Future<Either<Failure, Unit>> persistTerminalWrite(
    CollectionCallTerminalWrite write,
  );
}
