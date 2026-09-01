/// Closing Agent ADK client constants (not the Cloud Run URL — that is Envied).
abstract final class ClosingAgentConstants {
  /// ADK app directory / `appName` on `POST /run`.
  static const String appName = 'closing_agent';

  /// Pinned Vertex / ADK model id (must match `agent/closing_agent/agent.py`).
  static const String modelId = 'gemini-3.5-flash';

  /// TCP connect timeout for the dedicated agent Dio client.
  static const Duration connectTimeout = Duration(seconds: 15);

  /// Request-body send timeout.
  static const Duration sendTimeout = Duration(seconds: 30);

  /// Receive timeout — Vertex + Cloud Run min-instances 0 can be slow.
  static const Duration receiveTimeout = Duration(seconds: 120);

  /// Cloud Run PDF byte cap (must match `agent/email_send/schemas.py`).
  static const int maxPdfBytes = 5 * 1024 * 1024;

  /// J.7 send-set cap (must match `agent/email_send/schemas.py` `MAX_RECIPIENTS`).
  static const int maxEmailRecipients = 20;

  /// MIME statement PDFs only on ranked Top 5 of the send set.
  static const int statementSetSize = 5;

  /// Send timeout for multipart send-batch (up to five PDFs near the cap).
  static const Duration emailSendBatchSendTimeout = Duration(seconds: 180);

  /// Receive timeout for send-batch (20 SMTP + ~1s stagger + cold start).
  static const Duration emailSendBatchReceiveTimeout = Duration(seconds: 240);

  /// Typed `goalText` when the utterance is a WAV clip (OpenAPI minLength 1).
  static const String voiceGoalSentinel = '__voice__';

  /// Appendix J.2 marker — not a second copy of the bytes.
  static const String inlineAudioRefWav = 'inline:audio/wav';

  /// Hold-to-talk sample rate (Gemini 3.5 Flash `audio/wav`).
  static const int voiceSampleRateHz = 16000;

  /// Contest utterances are seconds; hard cap on capture.
  static const Duration maxVoiceCapture = Duration(seconds: 20);

  /// Chirp 3 HD unary cap (must match `agent/tts/voices.py` `MAX_TTS_CHARS`).
  static const int maxTtsChars = 2000;

  /// Send timeout for `POST /v1/tts`.
  static const Duration ttsSendTimeout = Duration(seconds: 15);

  /// Receive timeout for Chirp 3 HD + Cloud Run cold start.
  static const Duration ttsReceiveTimeout = Duration(seconds: 30);

  static final _localDayPattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

  /// Formats [now] as merchant `localDay` `YYYY-MM-DD` in the device timezone.
  static String merchantLocalDay([DateTime? now]) {
    final local = (now ?? DateTime.now()).toLocal();
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  /// UTC half-open range for [localDay] in the device timezone, or null if invalid.
  ///
  /// [now] is the clock used to format [localDay] (tests freeze it). Bounds are
  /// still the device-local calendar date, not wall-clock time of [now].
  static ({DateTime startUtc, DateTime endUtc})? utcBoundsForLocalDay(
    String localDay, {
    DateTime? now,
  }) {
    final match = _localDayPattern.firstMatch(localDay.trim());
    if (match == null) {
      return null;
    }
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    final startLocal = DateTime(year, month, day);
    if (startLocal.year != year ||
        startLocal.month != month ||
        startLocal.day != day) {
      return null;
    }
    // [now] is the clock used to format [localDay]; bounds use device TZ.
    final _ = now?.isUtc;
    return (
      startUtc: startLocal.toUtc(),
      endUtc: startLocal.add(const Duration(days: 1)).toUtc(),
    );
  }
}
