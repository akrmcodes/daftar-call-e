import 'package:daftar/core/utils/voice_capture.dart';
import 'package:daftar/domain/value_objects/agent_audio_clip.dart';
import 'package:permission_handler/permission_handler.dart';

/// Result of attempting to start a hold-to-talk capture.
enum ClosingMicHoldBegin {
  /// Native recorder is running; UI may show a recording affordance.
  started,

  /// Mic denied, permanently denied, or restricted — show the permission banner.
  denied,

  /// Permission granted but the recorder failed — same merchant action as deny.
  failed,

  /// Already recording, still starting, or already disposed.
  ignored,
}

/// Crash-safe hold-to-talk lock around [VoiceCapture].
///
/// [isRecording] is true only after a successful [begin]. Dispose, background
/// interrupt, deny, and recorder failure all leave it false. Never throws.
class ClosingMicHoldSession {
  /// Creates a session. Inject [capture] in tests.
  ClosingMicHoldSession({VoiceCapture? capture})
    : _capture = capture ?? VoiceCapture();

  final VoiceCapture _capture;
  bool _isRecording = false;
  bool _starting = false;
  bool _disposed = false;

  /// True only while a WAV capture is in progress.
  bool get isRecording => _isRecording;

  /// Live amplitude stream while recording; null when idle or unsupported.
  Stream<double>? amplitudeStream({
    Duration interval = const Duration(milliseconds: 80),
  }) {
    if (!_isRecording) {
      return null;
    }
    return _capture.amplitude(interval: interval);
  }

  /// Current OS microphone status. Never requests. Never throws.
  Future<PermissionStatus> currentStatus() => _capture.currentStatus();

  /// Requests (or short-circuits) microphone access, then starts capture.
  Future<ClosingMicHoldBegin> begin() async {
    if (_disposed || _isRecording || _starting) {
      return ClosingMicHoldBegin.ignored;
    }
    _starting = true;
    try {
      final status = await _capture.requestPermission();
      if (_disposed) {
        return ClosingMicHoldBegin.ignored;
      }
      if (!status.isGranted) {
        return ClosingMicHoldBegin.denied;
      }
      final started = await _capture.start();
      if (_disposed) {
        await _capture.cancel();
        return ClosingMicHoldBegin.ignored;
      }
      if (!started) {
        return ClosingMicHoldBegin.failed;
      }
      _isRecording = true;
      return ClosingMicHoldBegin.started;
    } on Object catch (_) {
      _isRecording = false;
      try {
        await _capture.cancel();
      } on Object catch (_) {}
      return ClosingMicHoldBegin.failed;
    } finally {
      _starting = false;
    }
  }

  /// Stops capture and returns the clip, or null if nothing to submit.
  Future<AgentAudioClip?> end() async {
    if (!_isRecording) {
      return null;
    }
    _isRecording = false;
    try {
      return await _capture.stop();
    } on Object catch (_) {
      return null;
    }
  }

  /// Drops the in-progress clip. Safe when idle.
  Future<void> cancel() async {
    _isRecording = false;
    try {
      await _capture.cancel();
    } on Object catch (_) {}
  }

  /// Cancels an in-progress hold when the app is paused (Settings / audio kill).
  Future<void> abandonForBackground() => cancel();

  /// Releases the native recorder. Further [begin] calls are ignored.
  Future<void> dispose() async {
    _disposed = true;
    _isRecording = false;
    try {
      await _capture.dispose();
    } on Object catch (_) {}
  }
}
