import 'dart:async';

import 'package:daftar/core/utils/device_tts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    DeviceTts.debugSpeakOverride = null;
    DeviceTts.debugStopOverride = null;
    DeviceTts.debugReset();
  });

  group('resolveLanguageTag', () {
    test('prefers ar-SA then other Arabic tags', () {
      expect(
        DeviceTts.resolveLanguageTag(
          locale: 'ar',
          available: const ['en-US', 'ar-EG', 'ar-SA'],
        ),
        'ar-SA',
      );
      expect(
        DeviceTts.resolveLanguageTag(
          locale: 'ar',
          available: const ['en-US', 'ar-EG'],
        ),
        'ar-EG',
      );
    });

    test('accepts underscore Android tags and falls back to en-US', () {
      expect(
        DeviceTts.resolveLanguageTag(
          locale: 'ar',
          available: const ['ar_SA', 'en_US'],
        ),
        'ar-SA',
      );
      expect(
        DeviceTts.resolveLanguageTag(
          locale: 'ar',
          available: const ['en-US', 'fr-FR'],
        ),
        'en-US',
      );
    });

    test('English locale prefers en-US', () {
      expect(
        DeviceTts.resolveLanguageTag(
          locale: 'en',
          available: const ['en-GB', 'en-US', 'ar-SA'],
        ),
        'en-US',
      );
    });

    test('returns null when the engine has no languages', () {
      expect(
        DeviceTts.resolveLanguageTag(locale: 'ar', available: const []),
        isNull,
      );
    });
  });

  test('speaks are serialized so the second waits for the first', () async {
    final order = <String>[];
    DeviceTts.debugSpeakOverride = (text, {required locale}) async {
      order.add('start-$text');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      order.add('end-$text');
    };

    unawaited(DeviceTts.speak('a', locale: 'en'));
    unawaited(DeviceTts.speak('b', locale: 'en'));
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(order, ['start-a', 'end-a', 'start-b', 'end-b']);
  });

  test('stop skips a queued utterance', () async {
    final started = <String>[];
    DeviceTts.debugSpeakOverride = (text, {required locale}) async {
      started.add(text);
      await Future<void>.delayed(const Duration(milliseconds: 40));
    };

    final first = DeviceTts.speak('a', locale: 'en');
    final second = DeviceTts.speak('b', locale: 'en');
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await DeviceTts.stop();
    await first;
    await second;

    expect(started.contains('b'), isFalse);
  });
}
