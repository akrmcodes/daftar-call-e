import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/utils/uuid_util.dart';
import 'package:daftar/domain/entities/agent_outbox_item.dart';
import 'package:daftar/domain/enums/agent_outbox_status.dart';
import 'package:daftar/domain/repositories/agent_outbox_repository.dart';
import 'package:fpdart/fpdart.dart';

/// Enqueues a thin agent-outbox item (processors land in Stage 5).
class EnqueueAgentOutboxItemUseCase {
  /// Creates the use case.
  const EnqueueAgentOutboxItemUseCase(this._agentOutboxRepository);

  final AgentOutboxRepository _agentOutboxRepository;

  /// Inserts a `queued` outbox row with a generated UUID.
  Future<Either<Failure, AgentOutboxItem>> execute({
    required String kind,
    required String payloadJson,
    DateTime? nextRetryAt,
  }) async {
    final trimmedKind = kind.trim();
    if (trimmedKind.isEmpty) {
      return const Left(
        ValidationFailure(
          'Outbox kind is required.',
          code: 'outbox_kind_required',
        ),
      );
    }

    final trimmedPayload = payloadJson.trim();
    if (trimmedPayload.isEmpty) {
      return const Left(
        ValidationFailure(
          'Outbox payloadJson is required.',
          code: 'outbox_payload_required',
        ),
      );
    }

    final now = DateTime.now().toUtc();
    final item = AgentOutboxItem(
      id: UuidUtil.generate(),
      kind: trimmedKind,
      status: AgentOutboxStatus.queued,
      payloadJson: trimmedPayload,
      createdAt: now,
      updatedAt: now,
      nextRetryAt: nextRetryAt?.toUtc(),
    );

    return _agentOutboxRepository.enqueue(item);
  }
}
