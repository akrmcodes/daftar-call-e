import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/value_objects/agent_audio_clip.dart';
import 'package:daftar/domain/value_objects/agent_turn_result.dart';
import 'package:daftar/domain/value_objects/device_agent_request.dart';
import 'package:daftar/domain/value_objects/email_send_batch.dart';
import 'package:fpdart/fpdart.dart';

/// Remote ADK runtime on authenticated Cloud Run (no Drift).
abstract class ClosingAgentRuntimeRepository {
  /// `GET /list-apps` — smoke / connectivity.
  Future<Either<Failure, List<String>>> listApps();

  /// `POST /apps/{app}/users/{userId}/sessions/{sessionId}`.
  Future<Either<Failure, Unit>> createOrUpdateSession({
    required String userId,
    required String sessionId,
    required DeviceAgentRequest context,
  });

  /// `POST /run` — one agent turn. Parses tool proposals from ADK events.
  Future<Either<Failure, AgentTurnResult>> runTurn({
    required String userId,
    required String sessionId,
    required DeviceAgentRequest context,
    AgentAudioClip? audio,
  });

  /// `POST /v1/email/send-batch` — J.7 multipart SMTP (never App Password).
  Future<Either<Failure, EmailSendBatchResponse>> sendEmailBatch(
    EmailSendBatchRequest request,
  );
}
