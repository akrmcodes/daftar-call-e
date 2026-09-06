import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/data/datasources/local/collection_call_local_ds.dart';
import 'package:daftar/data/mappers/collection_promise_mapper.dart';
import 'package:daftar/data/repositories/repository_utils.dart';
import 'package:daftar/domain/entities/collection_promise.dart';
import 'package:daftar/domain/repositories/collection_call_repository.dart';
import 'package:daftar/domain/value_objects/collection_call_persist.dart';
import 'package:fpdart/fpdart.dart';

/// Drift-backed [CollectionCallRepository].
class CollectionCallRepositoryImpl implements CollectionCallRepository {
  /// Creates the repository.
  CollectionCallRepositoryImpl({
    required CollectionCallLocalDataSource localDataSource,
  }) : _local = localDataSource;

  final CollectionCallLocalDataSource _local;

  @override
  Future<Either<Failure, Unit>> persistQueuedBatch(
    CollectionCallBatchSeed seed,
  ) async {
    try {
      await _local.persistQueuedBatch(seed);
      return const Right(unit);
    } on Object catch (error) {
      return Left(databaseFailure(error));
    }
  }

  @override
  Future<Either<Failure, Unit>> persistTerminalWrite(
    CollectionCallTerminalWrite write,
  ) async {
    try {
      await _local.persistTerminalWrite(write);
      return const Right(unit);
    } on Object catch (error) {
      return Left(databaseFailure(error));
    }
  }

  @override
  Stream<List<CollectionPromise>> watchPendingByContact(String contactId) {
    return _local
        .watchPendingPromisesByContact(contactId)
        .map(
          (rows) =>
              rows.map((row) => row.toDomain()).toList(growable: false),
        );
  }
}
