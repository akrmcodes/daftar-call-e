import 'package:daftar/core/utils/agent_speech.dart';

/// Spoken closing report. Cloud Chirp first; mute is a no-op.
abstract final class ClosingReportSpeech {
  /// Announces [text] when a closing report is shown.
  static Future<void> announce(
    String text, {
    required bool muted,
    required String locale,
  }) async {
    if (muted || text.trim().isEmpty) {
      return;
    }
    await AgentSpeech.speak(text, locale: locale, muted: muted);
  }
}
