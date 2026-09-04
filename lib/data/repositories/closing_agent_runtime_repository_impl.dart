import 'package:daftar/core/errors/edge_error_codes.dart';
import 'package:daftar/core/errors/exceptions.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/data/datasources/remote/closing_agent_remote_ds.dart';
import 'package:daftar/data/datasources/remote/edge_function_errors.dart';
import 'package:daftar/data/mappers/adk_event_proposal_mapper.dart';
import 'package:daftar/domain/repositories/closing_agent_runtime_repository.dart';
import 'package:daftar/domain/value_objects/agent_audio_clip.dart';
import 'package:daftar/domain/value_objects/agent_turn_result.dart';
import 'package:daftar/domain/value_objects/call_get_result.dart';
import 'package:daftar/domain/value_objects/call_plan_batch.dart';
import 'package:daftar/domain/value_objects/call_run_batch.dart';
import 'package:daftar/domain/value_objects/device_agent_request.dart';
import 'package:daftar/domain/value_objects/email_send_batch.dart';
import 'package:fpdart/fpdart.dart';

/// Maps Cloud Run / ADK transport errors to [Failure].
class ClosingAgentRuntimeRepositoryImpl
    implements ClosingAgentRuntimeRepository {
  /// Creates the repository.
  ClosingAgentRuntimeRepositoryImpl({
    required ClosingAgentRemoteDs remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  final ClosingAgentRemoteDs _remoteDataSource;

  @override
  Future<Either<Failure, List<String>>> listApps() async {
    try {
      return Right(await _remoteDataSource.listApps());
    } on Object catch (error) {
      return Left(_toFailure(error));
    }
  }

  @override
  Future<Either<Failure, Unit>> createOrUpdateSession({
    required String userId,
    required String sessionId,
    required DeviceAgentRequest context,
  }) async {
    try {
      await _remoteDataSource.createOrUpdateSession(
        userId: userId,
        sessionId: sessionId,
        context: context,
      );
      return const Right(unit);
    } on Object catch (error) {
      return Left(_toFailure(error));
    }
  }

  @override
  Future<Either<Failure, AgentTurnResult>> runTurn({
    required String userId,
    required String sessionId,
    required DeviceAgentRequest context,
    AgentAudioClip? audio,
  }) async {
    try {
      return Right(
        await _remoteDataSource.runTurn(
          userId: userId,
          sessionId: sessionId,
          context: context,
          audio: audio,
        ),
      );
    } on Object catch (error) {
      return Left(_toFailure(error));
    }
  }

  @override
  Future<Either<Failure, EmailSendBatchResponse>> sendEmailBatch(
    EmailSendBatchRequest request,
  ) async {
    try {
      return Right(await _remoteDataSource.sendEmailBatch(request));
    } on Object catch (error) {
      return Left(_toFailure(error));
    }
  }

  @override
  Future<Either<Failure, CallPlanBatchResponse>> planCallBatch(
    CallPlanBatchRequest request,
  ) async {
    try {
      return Right(await _remoteDataSource.planCallBatch(request));
    } on Object catch (error) {
      return Left(_toFailure(error));
    }
  }

  @override
  Future<Either<Failure, CallRunBatchResponse>> runCallBatch(
    CallRunBatchRequest request,
  ) async {
    try {
      return Right(await _remoteDataSource.runCallBatch(request));
    } on Object catch (error) {
      return Left(_toFailure(error));
    }
  }

  @override
  Future<Either<Failure, CallGetResult>> getCallRun(String runId) async {
    try {
      return Right(await _remoteDataSource.getCallRun(runId));
    } on Object catch (error) {
      return Left(_toFailure(error));
    }
  }

  Failure _toFailure(Object error) {
    if (error is AuthException) {
      return AuthFailure(error.message, code: 'agent_id_token_missing');
    }
    if (error is ProposalParseException) {
      return ValidationFailure(error.message, code: error.code);
    }
    if (error is ServerException) {
      final code = error.errorCode ?? edgeCodeForStatus(error.statusCode);
      if (code == 'calle_kill_switch') {
        return AuthFailure(error.message, code: 'calle_kill_switch');
      }
      if (code == EdgeErrorCodes.unauthorized) {
        return AuthFailure(
          error.message,
          code: 'closing_agent_unauthorized',
        );
      }
      if (code == EdgeErrorCodes.forbidden) {
        return AuthFailure(
          error.message,
          code: 'closing_agent_forbidden',
        );
      }
      if (code == EdgeErrorCodes.serviceUnavailable) {
        return NetworkFailure(
          error.message,
          code: 'closing_agent_request_failed',
        );
      }
      return mapEdgeFunctionFailure(
        error,
        fallbackCode: 'closing_agent_request_failed',
      );
    }
    return NetworkFailure(
      'Closing Agent request failed: $error',
      code: 'closing_agent_request_failed',
    );
  }
}
