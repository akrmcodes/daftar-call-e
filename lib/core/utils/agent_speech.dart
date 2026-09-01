import 'dart:async';
import 'dart:developer' as developer;

import 'package:audio_session/audio_session.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/utils/device_tts.dart';
import 'package:daftar/core/utils/speech_script_locale.dart';
import 'package:daftar/core/utils/tts_sanitize.dart';
import 'package:daftar/domain/value_objects/agent_speech_clip.dart';
import 'package:flutter/foundation.dart';
import 'package:fpdart/fpdart.dart';
import 'package:just_audio/just_audio.dart';

/// Cloud Chirp 3 HD playback with on-device [DeviceTts] fail-soft.
///
/// Plugins stay out of domain/application. Speaks are serialized so narrative
/// is not overlapped by confirm read-back.
abstract final class AgentSpeech {
  static AgentSpeechSynthesize? _synthesize;
  static Future<bool> Function()? _isOnline;
  static AudioPlayer? _player;
  static Future<void> _tail = Future<void>.value();
  static int _epoch = 0;
  static final Map<String, AgentSpeechClip> _cache =
      <String, AgentSpeechClip>{};

  static const int _maxCache = 32;

  /// Test hook. When set, [speak] uses this instead of the bound use case.
  static AgentSpeechSynthesize? debugSynthesizeOverride;

  /// Test hook. When set, MP3 playback skips `just_audio`.
  static Future<void> Function(Uint8List bytes, {required String mimeType})?
  debugPlayOverride;

  /// Test hook. When set, [stop] still stops [DeviceTts] after this runs.
  static Future<void> Function()? debugStopOverride;

  /// Wires the application use case. Call from the Closing Agent controller.
  static void bind({
    required AgentSpeechSynthesize synthesize,
    Future<bool> Function()? isOnline,
  }) {
    _synthesize = synthesize;
    _isOnline = isOnline;
  }

  /// Drops the bound use case (tests / provider dispose).
  static void unbind() {
    _synthesize = null;
    _isOnline = null;
  }

  /// Clears queue, cache, player, and binds. Tests only.
  @visibleForTesting
  static void debugReset() {
    _epoch++;
    _tail = Future<void>.value();
    _cache.clear();
    unbind();
    debugSynthesizeOverride = null;
    debugPlayOverride = null;
    debugStopOverride = null;
    final player = _player;
    _player = null;
    if (player != null) {
      unawaited(player.dispose());
    }
  }

  /// Speaks [text] for [locale]. Cloud first; [DeviceTts] on any failure.
  static Future<void> speak(
    String text, {
    required String locale,
    bool muted = false,
  }) async {
    final trimmed = sanitizeForTts(text);
    if (muted || trimmed.isEmpty) {
      return;
    }
    final epoch = _epoch;
    final previous = _tail;
    final gate = Completer<void>();
    _tail = gate.future;
    final resolved = coerceLocaleToTextScript(locale: locale, text: trimmed);
    try {
      await previous;
      if (epoch != _epoch) {
        return;
      }
      final played = await _tryCloud(trimmed, locale: resolved, epoch: epoch);
      if (played || epoch != _epoch) {
        return;
      }
      await DeviceTts.speak(trimmed, locale: resolved);
    } on Object catch (error, stackTrace) {
      _log('speak failed', error, stackTrace);
      if (epoch == _epoch) {
        await DeviceTts.speak(trimmed, locale: resolved);
      }
    } finally {
      if (!gate.isCompleted) {
        gate.complete();
      }
    }
  }

  /// Stops in-flight cloud and device speech (new recording, new turn, pop).
  static Future<void> stop() async {
    _epoch++;
    final override = debugStopOverride;
    if (override != null) {
      await override();
    }
    try {
      await _player?.stop();
    } on Object catch (error, stackTrace) {
      _log('player stop failed', error, stackTrace);
    }
    await DeviceTts.stop();
  }

  static Future<bool> _tryCloud(
    String text, {
    required String locale,
    required int epoch,
  }) async {
    final synthesizer = debugSynthesizeOverride ?? _synthesize;
    if (synthesizer == null) {
      return false;
    }
    final onlineProbe = _isOnline;
    if (onlineProbe != null) {
      final online = await onlineProbe();
      if (!online) {
        return false;
      }
    }
    if (epoch != _epoch) {
      return false;
    }
    final cacheKey = '$locale|$text';
    var clip = _cache[cacheKey];
    if (clip == null) {
      final result = await synthesizer(text: text, locale: locale);
      if (epoch != _epoch) {
        return false;
      }
      clip = result.getRight().toNullable();
      if (clip == null || !clip.isNotEmpty) {
        return false;
      }
      _putCache(cacheKey, clip);
    }
    await _playMp3(clip.bytes, mimeType: clip.mimeType);
    return epoch == _epoch;
  }

  static void _putCache(String key, AgentSpeechClip clip) {
    _cache.remove(key);
    _cache[key] = clip;
    while (_cache.length > _maxCache) {
      _cache.remove(_cache.keys.first);
    }
  }

  static Future<void> _playMp3(
    Uint8List bytes, {
    required String mimeType,
  }) async {
    final override = debugPlayOverride;
    if (override != null) {
      await override(bytes, mimeType: mimeType);
      return;
    }
    await _ensurePlaybackSession();
    final player = _player ??= AudioPlayer();
    await player.stop();
    await player.setAudioSource(
      AudioSource.uri(Uri.dataFromBytes(bytes, mimeType: mimeType)),
    );
    await player.setVolume(1);
    await player.play();
  }

  static Future<void> _ensurePlaybackSession() async {
    if (kIsWeb) {
      return;
    }
    try {
      final session = await AudioSession.instance;
      await session.configure(
        const AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playback,
          avAudioSessionCategoryOptions:
              AVAudioSessionCategoryOptions.defaultToSpeaker,
          avAudioSessionMode: AVAudioSessionMode.spokenAudio,
          androidAudioAttributes: AndroidAudioAttributes(
            contentType: AndroidAudioContentType.speech,
            usage: AndroidAudioUsage.assistanceAccessibility,
          ),
          androidWillPauseWhenDucked: false,
        ),
      );
    } on Object catch (error, stackTrace) {
      _log('audio session failed', error, stackTrace);
    }
  }

  static void _log(String message, [Object? error, StackTrace? stackTrace]) {
    if (!kDebugMode) {
      return;
    }
    developer.log(
      message,
      name: 'AgentSpeech',
      error: error,
      stackTrace: stackTrace,
    );
  }
}

/// Bound synthesizer (`SynthesizeAgentSpeechUseCase.execute` or a test fake).
typedef AgentSpeechSynthesize =
    Future<Either<Failure, AgentSpeechClip>> Function({
      required String text,
      required String locale,
    });
