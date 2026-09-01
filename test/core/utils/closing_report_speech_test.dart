import 'package:daftar/core/utils/agent_speech.dart';
import 'package:daftar/core/utils/closing_report_speech.dart';
import 'package:daftar/core/utils/device_tts.dart';
import 'package:daftar/core/utils/voice_capture.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  tearDown(() {
    DeviceTts.debugSpeakOverride = null;
    DeviceTts.debugStopOverride = null;
    DeviceTts.debugReset();
    AgentSpeech.debugReset();
  });

  test('announce is a no-op when ttsMuted', () async {
    var spoken = 0;
    DeviceTts.debugSpeakOverride = (text, {required locale}) async {
      spoken += 1;
    };

    await ClosingReportSpeech.announce(
      'Day closed',
      muted: true,
      locale: 'en',
    );
    expect(spoken, 0);

    await ClosingReportSpeech.announce(
      'Day closed',
      muted: false,
      locale: 'en',
    );
    expect(spoken, 1);
  });

  test('announce speaks a full report script when unmuted', () async {
    final spoken = <String>[];
    DeviceTts.debugSpeakOverride = (text, {required locale}) async {
      spoken.add(text);
    };

    const script =
        "Day closed. Today you recorded 3 debts and 2 payments. Tonight's backup is on Google Drive. Your books are safe. That's the close for today";
    await ClosingReportSpeech.announce(script, muted: false, locale: 'en');
    expect(spoken, [script]);
  });

  test('denied microphone status is not granted', () async {
    final capture = VoiceCapture(
      microphoneStatus: () async => PermissionStatus.denied,
      requestMicrophone: () async => PermissionStatus.denied,
    );
    final status = await capture.requestPermission();
    expect(status.isGranted, isFalse);
    expect(status.isDenied, isTrue);
  });
}
