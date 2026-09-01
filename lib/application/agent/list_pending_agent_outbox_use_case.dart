import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/entities/agent_outbox_item.dart';
import 'package:daftar/domain/repositories/agent_outbox_repository.dart';
import 'package:fpdart/fpdart.dart';

/// Lists due agent-outbox items (`queued` / `retrying`).
class ListPendingAgentOutboxUseCase {
  /// Creates the use case.
  const ListPendingAgentOutboxUseCase(this._agentOutboxRepository);

  final AgentOutboxRepository _agentOutboxRepository;

  /// Returns items ready to process.
  Future<Either<Failure, List<AgentOutboxItem>>> execute() {
    return _agentOutboxRepository.listPending();
  }
}
