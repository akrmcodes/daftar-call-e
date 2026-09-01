import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/data/datasources/local/collections_send_queue_local_ds.dart';
import 'package:daftar/data/repositories/repository_utils.dart';
import 'package:daftar/domain/repositories/collections_send_queue_repository.dart';
import 'package:daftar/domain/value_objects/collections_send_queue.dart';
import 'package:fpdart/fpdart.dart';

/// Drift-backed [CollectionsSendQueueRepository].
class CollectionsSendQueueRepositoryImpl
    implements CollectionsSendQueueRepository {
  /// Creates the repository.
  CollectionsSendQueueRepositoryImpl({
    required CollectionsSendQueueLocalDataSource
    collectionsSendQueueLocalDataSource,
  }) : _local = collectionsSendQueueLocalDataSource;

  final CollectionsSendQueueLocalDataSource _local;

  @override
  Future<Either<Failure, CollectionsSendQueue?>> getInFlight() async {
    try {
      return Right(await _local.getInFlight());
    } on Object catch (error) {
      return Left(databaseFailure(error));
    }
  }

  @override
  Future<Either<Failure, Unit>> upsert(CollectionsSendQueue queue) async {
    try {
      await _local.upsert(queue);
      return const Right(unit);
    } on Object catch (error) {
      return Left(databaseFailure(error));
    }
  }

  @override
  Future<Either<Failure, Unit>> complete(String queueId) async {
    try {
      await _local.complete(queueId);
      return const Right(unit);
    } on Object catch (error) {
      return Left(databaseFailure(error));
    }
  }
}
