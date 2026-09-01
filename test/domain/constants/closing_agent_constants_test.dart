import 'package:daftar/domain/constants/closing_agent_constants.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('utcBoundsForLocalDay is half-open local calendar day', () {
    final bounds = ClosingAgentConstants.utcBoundsForLocalDay('2026-08-15');
    expect(bounds, isNotNull);
    final startLocal = bounds!.startUtc.toLocal();
    final endLocal = bounds.endUtc.toLocal();
    expect(startLocal.year, 2026);
    expect(startLocal.month, 8);
    expect(startLocal.day, 15);
    expect(startLocal.hour, 0);
    expect(endLocal.difference(startLocal), const Duration(days: 1));
  });

  test('utcBoundsForLocalDay rejects invalid dates', () {
    expect(ClosingAgentConstants.utcBoundsForLocalDay('2026-02-31'), isNull);
    expect(ClosingAgentConstants.utcBoundsForLocalDay('15-08-2026'), isNull);
    expect(ClosingAgentConstants.utcBoundsForLocalDay(''), isNull);
  });

  test('voice sentinel and inline audioRef are stable', () {
    expect(ClosingAgentConstants.voiceGoalSentinel, '__voice__');
    expect(ClosingAgentConstants.inlineAudioRefWav, 'inline:audio/wav');
    expect(ClosingAgentConstants.maxVoiceCapture, const Duration(seconds: 20));
    expect(ClosingAgentConstants.voiceSampleRateHz, 16000);
  });
}
