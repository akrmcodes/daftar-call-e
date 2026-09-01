import 'package:daftar/domain/enums/agent_session_mode.dart';
import 'package:daftar/domain/enums/agent_session_status.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'agent_session.freezed.dart';

/// A Closing Agent or mid-day capture session.
@freezed
abstract class AgentSession with _$AgentSession {
  const factory AgentSession({
    required String id,
    required AgentSessionMode mode,
    required AgentSessionStatus status,
    required DateTime startedAt,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? endedAt,
    String? correlationId,
    @Default(false) bool isDeleted,
    @Default(0) int syncVersion,
  }) = _AgentSession;
}
