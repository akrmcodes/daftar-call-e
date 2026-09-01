import 'dart:async';
import 'dart:io';

import 'package:daftar/core/utils/closing_mic_hold_session.dart';
import 'package:daftar/core/utils/voice_capture.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';

class _FakeRecorder implements VoiceRecorder {
  Object? startError;
  Completer<void>? startGate;
  Completer<void>? enteredStart;
  int startCount = 0;
  String? lastPath;

  @override
  Future<void> startWav({
    required String path,
    required int sampleRateHz,
  }) async {
    startCount += 1;
    lastPath = path;
    enteredStart?.complete();
    if (startGate != null) {
      await startGate!.future;
    }
    if (startError != null) {
      throw Exception('$startError');
    }
    await File(path).writeAsBytes(const [9, 8, 7]);
  }

  @override
  Future<String?> stop() async => lastPath;

  @override
  Future<void> cancel() async {}

  @override
  Future<void> dispose() async {}

  @override
  Stream<double>? amplitude({Duration interval = const Duration(milliseconds: 80)}) =>
      null;
}

void main() {
  late Directory tempDir;
  late _FakeRecorder recorder;

  ClosingMicHoldSession session({
    PermissionStatus status = PermissionStatus.granted,
    PermissionStatus request = PermissionStatus.granted,
    Future<PermissionStatus>? delayedRequest,
  }) {
    return ClosingMicHoldSession(
      capture: VoiceCapture(
        recorder: recorder,
        microphoneStatus: () async => status,
        requestMicrophone: () => delayedRequest ?? Future.value(request),
        tempDirectory: () async => tempDir,
      ),
    );
  }

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('daftar_mic_');
    recorder = _FakeRecorder();
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('denied never starts the recorder', () async {
    final hold = session(
      status: PermissionStatus.denied,
      request: PermissionStatus.denied,
    );
    final outcome = await hold.begin();
    expect(outcome, ClosingMicHoldBegin.denied);
    expect(hold.isRecording, isFalse);
    expect(recorder.startCount, 0);
  });

  test('permanentlyDenied never starts the recorder', () async {
    final hold = session(status: PermissionStatus.permanentlyDenied);
    final outcome = await hold.begin();
    expect(outcome, ClosingMicHoldBegin.denied);
    expect(hold.isRecording, isFalse);
    expect(recorder.startCount, 0);
  });

  test('recorder throw returns failed and is not recording', () async {
    recorder.startError = StateError('avsession');
    final hold = session();
    final outcome = await hold.begin();
    expect(outcome, ClosingMicHoldBegin.failed);
    expect(hold.isRecording, isFalse);
    expect(recorder.startCount, 1);
  });

  test('successful begin then end returns clip and clears recording', () async {
    final hold = session();
    expect(await hold.begin(), ClosingMicHoldBegin.started);
    expect(hold.isRecording, isTrue);
    final clip = await hold.end();
    expect(clip, isNotNull);
    expect(clip!.bytes, const [9, 8, 7]);
    expect(hold.isRecording, isFalse);
  });

  test('end while idle returns null', () async {
    final hold = session();
    expect(await hold.end(), isNull);
  });

  test('abandonForBackground while recording does not submit', () async {
    final hold = session();
    expect(await hold.begin(), ClosingMicHoldBegin.started);
    await hold.abandonForBackground();
    expect(hold.isRecording, isFalse);
    expect(await hold.end(), isNull);
  });

  test('dispose during permission request ignores begin', () async {
    final gate = Completer<PermissionStatus>();
    final hold = session(
      status: PermissionStatus.denied,
      delayedRequest: gate.future,
    );
    final beginFuture = hold.begin();
    await hold.dispose();
    gate.complete(PermissionStatus.granted);
    expect(await beginFuture, ClosingMicHoldBegin.ignored);
    expect(hold.isRecording, isFalse);
    expect(recorder.startCount, 0);
  });

  test('dispose during start cancels and ignores', () async {
    recorder
        ..startGate = Completer<void>()
        ..enteredStart = Completer<void>();
    final hold = session();
    final beginFuture = hold.begin();
    await recorder.enteredStart!.future;
    await hold.dispose();
    recorder.startGate!.complete();
    expect(await beginFuture, ClosingMicHoldBegin.ignored);
    expect(hold.isRecording, isFalse);
  });

  test('second begin while recording is ignored', () async {
    final hold = session();
    expect(await hold.begin(), ClosingMicHoldBegin.started);
    expect(await hold.begin(), ClosingMicHoldBegin.ignored);
    expect(recorder.startCount, 1);
  });

  test('cancel after deny never throws', () async {
    final hold = session(
      status: PermissionStatus.permanentlyDenied,
    );
    expect(await hold.begin(), ClosingMicHoldBegin.denied);
    await hold.cancel();
    await hold.dispose();
    expect(hold.isRecording, isFalse);
  });
}
