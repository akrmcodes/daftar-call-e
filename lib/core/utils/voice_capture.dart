import 'dart:async';
import 'dart:io';

import 'package:daftar/domain/constants/closing_agent_constants.dart';
import 'package:daftar/domain/value_objects/agent_audio_clip.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

/// Native WAV recorder port. Inject in tests; production wraps [AudioRecorder].
abstract class VoiceRecorder {
  /// Starts a 16-bit WAV session at [sampleRateHz] writing to [path].
  Future<void> startWav({
    required String path,
    required int sampleRateHz,
  });

  /// Stops the session and returns the file path, if any.
  Future<String?> stop();

  /// Abandons the session and deletes the in-progress file.
  Future<void> cancel();

  /// Releases native recorder resources.
  Future<void> dispose();

  /// Live normalized amplitude in `0..1`, or null when unsupported.
  Stream<double>? amplitude({Duration interval});
}

class _PluginVoiceRecorder implements VoiceRecorder {
  _PluginVoiceRecorder([AudioRecorder? recorder]) : _existing = recorder;

  final AudioRecorder? _existing;
  AudioRecorder? _created;

  AudioRecorder get _plugin => _existing ?? (_created ??= AudioRecorder());

  @override
  Future<void> startWav({
    required String path,
    required int sampleRateHz,
  }) {
    return _plugin.start(
      RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: sampleRateHz,
        numChannels: 1,
        androidConfig: const AndroidRecordConfig(manageBluetooth: false),
        audioInterruption: AudioInterruptionMode.none,
      ),
      path: path,
    );
  }

  @override
  Future<String?> stop() => _plugin.stop();

  @override
  Future<void> cancel() => _plugin.cancel();

  @override
  Future<void> dispose() async {
    await (_created ?? _existing)?.dispose();
  }

  @override
  Stream<double>? amplitude({Duration interval = const Duration(milliseconds: 80)}) {
    return _plugin
        .onAmplitudeChanged(interval)
        .map(_normalizeAmplitudeDb);
  }

  static double _normalizeAmplitudeDb(Amplitude sample) {
    const floorDb = -60.0;
    final db = sample.current;
    if (db <= floorDb) {
      return 0;
    }
    if (db >= 0) {
      return 1;
    }
    return ((db - floorDb) / -floorDb).clamp(0.0, 1.0);
  }
}

/// Hold-to-talk WAV capture for Closing Agent (16 kHz mono, 20s cap).
///
/// Permission and recorder failures never escape to the framework.
class VoiceCapture {
  /// Creates a capture session. Inject [recorder] / permission hooks in tests.
  VoiceCapture({
    VoiceRecorder? recorder,
    Future<PermissionStatus> Function()? requestMicrophone,
    Future<PermissionStatus> Function()? microphoneStatus,
    Future<Directory> Function()? tempDirectory,
  }) : _recorder = recorder ?? _PluginVoiceRecorder(),
       _requestMicrophone = requestMicrophone,
       _microphoneStatus = microphoneStatus,
       _tempDirectory = tempDirectory;

  final VoiceRecorder _recorder;
  final Future<PermissionStatus> Function()? _requestMicrophone;
  final Future<PermissionStatus> Function()? _microphoneStatus;
  final Future<Directory> Function()? _tempDirectory;

  String? _path;

  /// Current microphone status. Never requests. Never throws.
  Future<PermissionStatus> currentStatus() async {
    try {
      if (_microphoneStatus != null) {
        return _microphoneStatus();
      }
      return Permission.microphone.status;
    } on Object catch (_) {
      return PermissionStatus.denied;
    }
  }

  /// Requests microphone access. Never throws.
  ///
  /// Does not call `permission_handler` microphone request when the OS status is
  /// already granted, permanently denied, or restricted (iOS Settings toggle
  /// must go through the system Settings app — looping request is a no-op
  /// and can look like a crash after `openAppSettings`). A status probe
  /// failure is treated as denied and does not prompt.
  Future<PermissionStatus> requestPermission() async {
    try {
      final PermissionStatus current;
      try {
        current = _microphoneStatus != null
            ? await _microphoneStatus()
            : await Permission.microphone.status;
      } on Object catch (_) {
        return PermissionStatus.denied;
      }
      if (current.isGranted ||
          current.isPermanentlyDenied ||
          current.isRestricted) {
        return current;
      }
      if (_requestMicrophone != null) {
        return await _requestMicrophone();
      }
      return await Permission.microphone.request();
    } on Object catch (_) {
      return PermissionStatus.denied;
    }
  }

  /// Starts WAV recording to a temp file. Returns false on any failure.
  Future<bool> start() async {
    try {
      final dir = _tempDirectory != null
          ? await _tempDirectory()
          : await getTemporaryDirectory();
      _path =
          '${dir.path}/daftar_voice_${DateTime.now().millisecondsSinceEpoch}.wav';
      await _recorder.startWav(
        path: _path!,
        sampleRateHz: ClosingAgentConstants.voiceSampleRateHz,
      );
      return true;
    } on Object catch (_) {
      await _abandonPath();
      try {
        await _recorder.cancel();
      } on Object catch (_) {}
      return false;
    }
  }

  /// Stops recording and returns the clip, or null if empty / failed.
  Future<AgentAudioClip?> stop() async {
    String? path;
    try {
      path = await _recorder.stop();
    } on Object catch (_) {}
    path ??= _path;
    _path = null;
    if (path == null || path.isEmpty) {
      return null;
    }
    try {
      final file = File(path);
      if (!file.existsSync()) {
        return null;
      }
      final bytes = await file.readAsBytes();
      try {
        await file.delete();
      } on Object catch (_) {}
      if (bytes.isEmpty) {
        return null;
      }
      return AgentAudioClip(bytes: bytes);
    } on Object catch (_) {
      return null;
    }
  }

  /// Normalized live amplitude while recording, or null when unsupported.
  Stream<double>? amplitude({
    Duration interval = const Duration(milliseconds: 80),
  }) {
    return _recorder.amplitude(interval: interval);
  }

  /// Abandons the in-progress clip without submitting.
  Future<void> cancel() async {
    try {
      await _recorder.cancel();
    } on Object catch (_) {
      try {
        await _recorder.stop();
      } on Object catch (_) {}
    }
    await _abandonPath();
  }

  /// Releases the native recorder.
  Future<void> dispose() async {
    await cancel();
    try {
      await _recorder.dispose();
    } on Object catch (_) {}
  }

  Future<void> _abandonPath() async {
    final leftover = _path;
    _path = null;
    if (leftover == null) {
      return;
    }
    try {
      await File(leftover).delete();
    } on Object catch (_) {}
  }
}
