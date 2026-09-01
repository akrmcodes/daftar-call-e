import 'package:daftar/application/agent/speech_locale.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/utils/tts_sanitize.dart';
import 'package:daftar/domain/constants/closing_agent_constants.dart';
import 'package:daftar/domain/repositories/agent_speech_repository.dart';
import 'package:daftar/domain/value_objects/agent_speech_clip.dart';
import 'package:fpdart/fpdart.dart';

/// Synthesizes one agent utterance via Cloud Run Chirp 3 HD.
class SynthesizeAgentSpeechUseCase {
  /// Creates the use case.
  const SynthesizeAgentSpeechUseCase({
    required AgentSpeechRepository repository,
  }) : _repository = repository;

  final AgentSpeechRepository _repository;

  /// Returns MP3 bytes, or [Left] so playback can fail-soft to device TTS.
  Future<Either<Failure, AgentSpeechClip>> execute({
    required String text,
    required String locale,
  }) async {
    final sanitized = sanitizeForTts(text);
    if (sanitized.isEmpty) {
      return const Left(
        ValidationFailure(
          'TTS text is required.',
          code: 'tts_text_required',
        ),
      );
    }
    if (sanitized.length > ClosingAgentConstants.maxTtsChars) {
      return const Left(
        ValidationFailure(
          'TTS text exceeds cap.',
          code: 'tts_text_too_long',
        ),
      );
    }
    return _repository.synthesize(
      text: sanitized,
      locale: coerceLocaleToTextScript(locale: locale, text: sanitized),
    );
  }
}
