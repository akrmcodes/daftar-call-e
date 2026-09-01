import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/data/datasources/local/agent_outbox_local_ds.dart';
import 'package:daftar/data/datasources/local/drift_database.dart' as db;
import 'package:daftar/data/models/agent_outbox_item_model.dart';
import 'package:daftar/data/repositories/repository_utils.dart';
import 'package:daftar/domain/entities/agent_outbox_item.dart';
import 'package:daftar/domain/repositories/agent_outbox_repository.dart';
import 'package:fpdart/fpdart.dart';

/// Drift-backed implementation of [AgentOutboxRepository].
class AgentOutboxRepositoryImpl implements AgentOutboxRepository {
  /// Creates an agent-outbox repository implementation.
  AgentOutboxRepositoryImpl({
    required AgentOutboxLocalDataSource agentOutboxLocalDataSource,
  }) : _agentOutboxLocalDataSource = agentOutboxLocalDataSource;

  final AgentOutboxLocalDataSource _agentOutboxLocalDataSource;

  db.AppDatabase get _database => _agentOutboxLocalDataSource.database;

  @override
  Future<Either<Failure, AgentOutboxItem>> enqueue(
    AgentOutboxItem item,
  ) async {
    try {
      final model = AgentOutboxItemModel.fromDomain(item);
      await _database.transaction(() async {
        await _agentOutboxLocalDataSource.insertItem(model);
      });
      return Right(model.toDomain());
    } on Object catch (error) {
      return Left(databaseFailure(error));
    }
  }

  @override
  Future<Either<Failure, List<AgentOutboxItem>>> listPending() async {
    try {
      final rows = await _agentOutboxLocalDataSource.listPending();
      return Right(
        rows.map((row) => row.toDomain()).toList(growable: false),
      );
    } on Object catch (error) {
      return Left(databaseFailure(error));
    }
  }
}
