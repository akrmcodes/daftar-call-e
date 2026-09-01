import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/value_objects/agent_speech_clip.dart';
import 'package:fpdart/fpdart.dart';

/// Cloud Chirp 3 HD synthesis on authenticated Cloud Run (no Drift).
abstract class AgentSpeechRepository {
  /// `POST /v1/tts` — unary MP3. Never logs [text].
  Future<Either<Failure, AgentSpeechClip>> synthesize({
    required String text,
    required String locale,
  });
}
