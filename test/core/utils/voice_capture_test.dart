import 'dart:io';

import 'package:daftar/core/utils/voice_capture.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';

class _FakeRecorder implements VoiceRecorder {
  Object? startError;
  Object? stopError;
  Object? cancelError;
  bool writeFile = true;
  bool returnDirectoryOnStop = false;
  int startCount = 0;
  int cancelCount = 0;
  String? lastPath;

  @override
  Future<void> startWav({
    required String path,
    required int sampleRateHz,
  }) async {
    startCount += 1;
    lastPath = path;
    if (startError != null) {
      throw Exception('$startError');
    }
    if (writeFile) {
      await File(path).writeAsBytes(const [1, 2, 3]);
    }
  }

  @override
  Future<String?> stop() async {
    if (stopError != null) {
      throw Exception('$stopError');
    }
    if (returnDirectoryOnStop && lastPath != null) {
      return File(lastPath!).parent.path;
    }
    return lastPath;
  }

  @override
  Future<void> cancel() async {
    cancelCount += 1;
    if (cancelError != null) {
      throw Exception('$cancelError');
    }
  }

  @override
  Future<void> dispose() async {}

  @override
  Stream<double>? amplitude({Duration interval = const Duration(milliseconds: 80)}) =>
      null;
}

void main() {
  late Directory tempDir;
  late _FakeRecorder recorder;
  var statusCalls = 0;
  var requestCalls = 0;
  late PermissionStatus status;
  late PermissionStatus requestResult;
  Object? statusError;
  Object? requestError;

  VoiceCapture capture() {
    return VoiceCapture(
      recorder: recorder,
      microphoneStatus: () async {
        statusCalls += 1;
        if (statusError != null) {
          throw Exception('$statusError');
        }
        return status;
      },
      requestMicrophone: () async {
        requestCalls += 1;
        if (requestError != null) {
          throw Exception('$requestError');
        }
        return requestResult;
      },
      tempDirectory: () async => tempDir,
    );
  }

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('daftar_voice_');
    recorder = _FakeRecorder();
    statusCalls = 0;
    requestCalls = 0;
    status = PermissionStatus.denied;
    requestResult = PermissionStatus.granted;
    statusError = null;
    requestError = null;
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('permanentlyDenied does not call request()', () async {
    status = PermissionStatus.permanentlyDenied;
    final result = await capture().requestPermission();
    expect(result, PermissionStatus.permanentlyDenied);
    expect(statusCalls, 1);
    expect(requestCalls, 0);
  });

  test('restricted does not call request()', () async {
    status = PermissionStatus.restricted;
    final result = await capture().requestPermission();
    expect(result, PermissionStatus.restricted);
    expect(requestCalls, 0);
  });

  test('already granted does not call request()', () async {
    status = PermissionStatus.granted;
    final result = await capture().requestPermission();
    expect(result.isGranted, isTrue);
    expect(requestCalls, 0);
  });

  test('denied status calls request() once', () async {
    status = PermissionStatus.denied;
    requestResult = PermissionStatus.denied;
    final result = await capture().requestPermission();
    expect(result.isGranted, isFalse);
    expect(requestCalls, 1);
  });

  test('permission hooks that throw map to denied', () async {
    statusError = StateError('plugin missing');
    final result = await capture().requestPermission();
    expect(result, PermissionStatus.denied);
    expect(requestCalls, 0);
  });

  test('start plugin throw returns false and leaves no wav', () async {
    recorder.startError = StateError('no mic');
    final started = await capture().start();
    expect(started, isFalse);
    expect(recorder.startCount, 1);
    expect(recorder.cancelCount, 1);
    expect(tempDir.listSync().whereType<File>(), isEmpty);
  });

  test('successful start/stop returns bytes and deletes the wav', () async {
    final voice = capture();
    expect(await voice.start(), isTrue);
    final clip = await voice.stop();
    expect(clip, isNotNull);
    expect(clip!.bytes, const [1, 2, 3]);
    expect(tempDir.listSync().whereType<File>(), isEmpty);
  });

  test('stop with missing file returns null', () async {
    recorder.writeFile = false;
    final voice = capture();
    expect(await voice.start(), isTrue);
    expect(await voice.stop(), isNull);
  });

  test(
    'stop plugin throw falls back to path then still returns bytes',
    () async {
      recorder.stopError = StateError('stop failed');
      final voice = capture();
      expect(await voice.start(), isTrue);
      final clip = await voice.stop();
      expect(clip, isNotNull);
      expect(clip!.bytes, const [1, 2, 3]);
    },
  );

  test('stop read throw (directory path) returns null', () async {
    recorder.returnDirectoryOnStop = true;
    final voice = capture();
    expect(await voice.start(), isTrue);
    expect(await voice.stop(), isNull);
  });

  test('cancel and dispose after failed start never throw', () async {
    recorder
      ..startError = StateError('denied')
      ..cancelError = StateError('already gone');
    final voice = capture();
    expect(await voice.start(), isFalse);
    await voice.cancel();
    await voice.dispose();
  });
}
