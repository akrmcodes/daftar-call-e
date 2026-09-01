import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// On-device TTS wrapper. Flutter plugins stay out of domain/application.
///
/// Fail-soft if the engine is missing or lacks Arabic — Confirm card UI
/// remains the source of truth. Speaks are serialized so narrative is not
/// flushed by confirm read-back.
abstract final class DeviceTts {
  static FlutterTts? _engine;
  static bool _ready = false;
  static Future<void> _tail = Future<void>.value();
  static int _epoch = 0;

  /// Test hook. When set, [speak] / [stop] skip the plugin.
  static Future<void> Function(String text, {required String locale})?
  debugSpeakOverride;

  static Future<void> Function()? debugStopOverride;

  /// Clears engine and the speak queue. Tests only.
  @visibleForTesting
  static void debugReset() {
    _epoch++;
    _tail = Future<void>.value();
    _engine = null;
    _ready = false;
  }

  /// Picks a BCP-47 tag from [available] for [locale] (`ar` / `en`).
  ///
  /// Prefers `ar-SA` then other Arabic tags, then `en-US`. Never returns a
  /// tag that is not in [available] unless [available] is empty (`null`).
  @visibleForTesting
  static String? resolveLanguageTag({
    required String locale,
    required Iterable<String> available,
  }) {
    final tags = [
      for (final raw in available) _normalize(raw),
    ].where((tag) => tag.isNotEmpty).toList(growable: false);
    final preferArabic = !locale.toLowerCase().startsWith('en');
    final preferred = preferArabic
        ? const ['ar-sa', 'ar', 'ar-eg', 'ar-ae', 'ar-iq', 'ar-jo', 'ar-lb']
        : const ['en-us', 'en', 'en-gb'];
    for (final candidate in preferred) {
      final hit = _match(tags, candidate);
      if (hit != null) {
        return _canonical(hit);
      }
    }
    if (preferArabic) {
      final anyAr = tags.where((tag) => tag.startsWith('ar')).firstOrNull;
      if (anyAr != null) {
        return _canonical(anyAr);
      }
      final en = _match(tags, 'en-us') ?? _match(tags, 'en');
      if (en != null) {
        return _canonical(en);
      }
    } else {
      final anyEn = tags.where((tag) => tag.startsWith('en')).firstOrNull;
      if (anyEn != null) {
        return _canonical(anyEn);
      }
    }
    if (tags.isEmpty) {
      return null;
    }
    return _canonical(tags.first);
  }

  /// Speaks [text] for [locale]. Queued behind in-flight utterances.
  static Future<void> speak(
    String text, {
    required String locale,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final epoch = _epoch;
    final previous = _tail;
    final gate = Completer<void>();
    _tail = gate.future;
    try {
      await previous;
      if (epoch != _epoch) {
        return;
      }
      final override = debugSpeakOverride;
      if (override != null) {
        await override(trimmed, locale: locale);
        return;
      }
      await _speakNative(trimmed, locale: locale, retry: true);
    } on Object catch (error, stackTrace) {
      _log('speak failed', error, stackTrace);
    } finally {
      if (!gate.isCompleted) {
        gate.complete();
      }
    }
  }

  /// Stops in-flight speech (new recording, new turn, screen pop).
  static Future<void> stop() async {
    _epoch++;
    final override = debugStopOverride;
    if (override != null) {
      await override();
      return;
    }
    try {
      await _engine?.stop();
    } on Object catch (error, stackTrace) {
      _log('stop failed', error, stackTrace);
    }
  }

  static Future<void> _speakNative(
    String text, {
    required String locale,
    required bool retry,
  }) async {
    final engine = await _ensureEngine();
    if (engine == null) {
      return;
    }
    try {
      if (!kIsWeb && Platform.isIOS) {
        await engine.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          const [
            IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
            IosTextToSpeechAudioCategoryOptions.allowBluetooth,
            IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
          ],
          IosTextToSpeechAudioMode.spokenAudio,
        );
      }
      final tag = await _pickEngineLanguage(engine, locale);
      if (tag != null) {
        final set = await engine.setLanguage(tag);
        if (!_isTruthy(set)) {
          _log('setLanguage($tag) declined');
        } else if (kDebugMode) {
          debugPrint('DeviceTts language=$tag');
        }
      }
      await engine.setVolume(1);
      final focus = !kIsWeb && Platform.isAndroid;
      final result = await engine.speak(text, focus: focus);
      if (kDebugMode) {
        debugPrint('DeviceTts speak result=$result');
      }
      if (_isTruthy(result)) {
        return;
      }
      if (retry) {
        _engine = null;
        _ready = false;
        await _speakNative(text, locale: locale, retry: false);
      }
    } on Object catch (error, stackTrace) {
      _log('native speak failed', error, stackTrace);
      if (retry) {
        _engine = null;
        _ready = false;
        await _speakNative(text, locale: locale, retry: false);
      }
    }
  }

  static Future<FlutterTts?> _ensureEngine() async {
    if (_engine != null && _ready) {
      return _engine;
    }
    try {
      final engine = _engine ??= FlutterTts();
      if (!kIsWeb && Platform.isIOS) {
        await engine.setSharedInstance(true);
      }
      await engine.setVolume(1);
      await engine.awaitSpeakCompletion(true);
      _ready = true;
      return engine;
    } on Object catch (error, stackTrace) {
      _log('engine init failed', error, stackTrace);
      return _engine;
    }
  }

  static Future<String?> _pickEngineLanguage(
    FlutterTts engine,
    String locale,
  ) async {
    final preferArabic = !locale.toLowerCase().startsWith('en');
    final candidates = preferArabic
        ? const ['ar-SA', 'ar', 'ar-EG', 'ar-AE', 'en-US']
        : const ['en-US', 'en', 'en-GB'];
    for (final candidate in candidates) {
      if (await _engineHasLanguage(engine, candidate)) {
        return candidate;
      }
    }
    try {
      final raw = await engine.getLanguages;
      if (raw is Iterable) {
        return resolveLanguageTag(
          locale: locale,
          available: [
            for (final item in raw) item.toString(),
          ],
        );
      }
    } on Object catch (error, stackTrace) {
      _log('getLanguages failed', error, stackTrace);
    }
    return preferArabic ? 'ar-SA' : 'en-US';
  }

  static Future<bool> _engineHasLanguage(
    FlutterTts engine,
    String tag,
  ) async {
    try {
      final available = await engine.isLanguageAvailable(tag);
      if (!_isTruthy(available)) {
        return false;
      }
    } on Object {
      return false;
    }
    if (kIsWeb || !Platform.isAndroid) {
      return true;
    }
    try {
      final installed = await engine.isLanguageInstalled(tag);
      if (installed == false || installed == 0) {
        return false;
      }
    } on Object {
      // iOS-shaped engines or older plugin paths: availability is enough.
    }
    return true;
  }

  static String _normalize(String raw) =>
      raw.trim().replaceAll('_', '-').toLowerCase();

  static String _canonical(String normalized) {
    final parts = normalized.split('-');
    if (parts.length == 1) {
      return parts.first;
    }
    return '${parts.first}-${parts.sublist(1).join('-').toUpperCase()}';
  }

  static String? _match(List<String> tags, String candidate) {
    for (final tag in tags) {
      if (tag == candidate) {
        return tag;
      }
    }
    for (final tag in tags) {
      if (tag.startsWith('$candidate-')) {
        return tag;
      }
    }
    for (final tag in tags) {
      if (candidate.startsWith('$tag-')) {
        return tag;
      }
    }
    return null;
  }

  static bool _isTruthy(Object? value) => value == true || value == 1;

  static void _log(String message, [Object? error, StackTrace? stackTrace]) {
    if (!kDebugMode) {
      return;
    }
    developer.log(
      message,
      name: 'DeviceTts',
      error: error,
      stackTrace: stackTrace,
    );
  }
}
