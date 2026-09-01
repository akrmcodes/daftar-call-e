import 'package:daftar/core/errors/edge_error_codes.dart';
import 'package:daftar/core/errors/exceptions.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/data/datasources/remote/closing_agent_remote_ds.dart';
import 'package:daftar/data/datasources/remote/edge_function_errors.dart';
import 'package:daftar/domain/repositories/agent_speech_repository.dart';
import 'package:daftar/domain/value_objects/agent_speech_clip.dart';
import 'package:fpdart/fpdart.dart';

/// Maps Cloud Run TTS transport errors to [Failure].
class AgentSpeechRepositoryImpl implements AgentSpeechRepository {
  /// Creates the repository.
  AgentSpeechRepositoryImpl({
    required ClosingAgentRemoteDs remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  final ClosingAgentRemoteDs _remoteDataSource;

  @override
  Future<Either<Failure, AgentSpeechClip>> synthesize({
    required String text,
    required String locale,
  }) async {
    try {
      return Right(
        await _remoteDataSource.synthesizeSpeech(
          text: text,
          locale: locale,
        ),
      );
    } on Object catch (error) {
      return Left(_toFailure(error));
    }
  }

  Failure _toFailure(Object error) {
    if (error is AuthException) {
      return AuthFailure(error.message, code: 'agent_id_token_missing');
    }
    if (error is ServerException) {
      final code = error.errorCode ?? edgeCodeForStatus(error.statusCode);
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
          code: 'agent_tts_failed',
        );
      }
      return mapEdgeFunctionFailure(
        error,
        fallbackCode: 'agent_tts_failed',
      );
    }
    return NetworkFailure(
      'Closing Agent TTS failed: $error',
      code: 'agent_tts_failed',
    );
  }
}
