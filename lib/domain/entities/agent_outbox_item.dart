import 'package:daftar/domain/enums/agent_outbox_status.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'agent_outbox_item.freezed.dart';

/// Thin local outbox row for pending agent work (Stage 5 processors).
@freezed
abstract class AgentOutboxItem with _$AgentOutboxItem {
  const factory AgentOutboxItem({
    required String id,
    required String kind,
    required AgentOutboxStatus status,
    required String payloadJson,
    required DateTime createdAt,
    required DateTime updatedAt,
    @Default(0) int attempts,
    DateTime? nextRetryAt,
  }) = _AgentOutboxItem;
}
