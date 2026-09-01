import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/value_objects/csv_bulk_persist_batch.dart';
import 'package:fpdart/fpdart.dart';

abstract class BulkWriteRepository {
  Future<Either<Failure, Unit>> persist(CsvBulkPersistBatch batch);
}
