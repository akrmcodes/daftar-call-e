import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/entities/agent_outbox_item.dart';
import 'package:fpdart/fpdart.dart';

/// Persistence contract for the thin local agent outbox.
abstract class AgentOutboxRepository {
  /// Enqueues [item] for later processing.
  Future<Either<Failure, AgentOutboxItem>> enqueue(AgentOutboxItem item);

  /// Returns queued/retrying items whose `nextRetryAt` is null or due.
  Future<Either<Failure, List<AgentOutboxItem>>> listPending();
}
