import 'dart:async';
import 'dart:typed_data';

import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/utils/agent_speech.dart';
import 'package:daftar/core/utils/device_tts.dart';
import 'package:daftar/domain/value_objects/agent_speech_clip.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

void main() {
  tearDown(() {
    DeviceTts.debugSpeakOverride = null;
    DeviceTts.debugStopOverride = null;
    DeviceTts.debugReset();
    AgentSpeech.debugReset();
  });

  test('muted skip does not synthesize or speak', () async {
    var synthesized = 0;
    var spoken = 0;
    AgentSpeech.bind(
      synthesize: ({required text, required locale}) async {
        synthesized += 1;
        return const Left(NetworkFailure('unused'));
      },
    );
    DeviceTts.debugSpeakOverride = (text, {required locale}) async {
      spoken += 1;
    };

    await AgentSpeech.speak('Hello', locale: 'en', muted: true);
    expect(synthesized, 0);
    expect(spoken, 0);
  });

  test('cloud Left falls back to DeviceTts', () async {
    final spoken = <String>[];
    AgentSpeech.bind(
      synthesize: ({required text, required locale}) async {
        return const Left(NetworkFailure('tts down', code: 'agent_tts_failed'));
      },
    );
    DeviceTts.debugSpeakOverride = (text, {required locale}) async {
      spoken.add(text);
    };

    await AgentSpeech.speak('Mohamed owes 500', locale: 'en');
    expect(spoken, ['Mohamed owes 500']);
  });

  test('cloud Right plays MP3 and skips DeviceTts', () async {
    final played = <int>[];
    var spoken = 0;
    AgentSpeech.bind(
      synthesize: ({required text, required locale}) async {
        return Right(
          AgentSpeechClip(bytes: Uint8List.fromList(const [1, 2, 3])),
        );
      },
    );
    AgentSpeech.debugPlayOverride = (bytes, {required mimeType}) async {
      played.add(bytes.length);
      expect(mimeType, 'audio/mpeg');
    };
    DeviceTts.debugSpeakOverride = (text, {required locale}) async {
      spoken += 1;
    };

    await AgentSpeech.speak('Hello', locale: 'en');
    expect(played, [3]);
    expect(spoken, 0);
  });

  test('offline probe skips cloud and uses DeviceTts', () async {
    var synthesized = 0;
    final spoken = <String>[];
    AgentSpeech.bind(
      synthesize: ({required text, required locale}) async {
        synthesized += 1;
        return Right(
          AgentSpeechClip(bytes: Uint8List.fromList(const [9])),
        );
      },
      isOnline: () async => false,
    );
    DeviceTts.debugSpeakOverride = (text, {required locale}) async {
      spoken.add(text);
    };

    await AgentSpeech.speak('Hello', locale: 'ar');
    expect(synthesized, 0);
    expect(spoken, ['Hello']);
  });

  test('same text+locale is cached', () async {
    var synthesized = 0;
    AgentSpeech.bind(
      synthesize: ({required text, required locale}) async {
        synthesized += 1;
        return Right(
          AgentSpeechClip(bytes: Uint8List.fromList(const [4, 5])),
        );
      },
    );
    AgentSpeech.debugPlayOverride = (bytes, {required mimeType}) async {};

    await AgentSpeech.speak('cached line', locale: 'en');
    await AgentSpeech.speak('cached line', locale: 'en');
    expect(synthesized, 1);
  });

  test('speaks are serialized', () async {
    final order = <String>[];
    AgentSpeech.bind(
      synthesize: ({required text, required locale}) async {
        return const Left(NetworkFailure('use device'));
      },
    );
    DeviceTts.debugSpeakOverride = (text, {required locale}) async {
      order.add('start-$text');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      order.add('end-$text');
    };

    unawaited(AgentSpeech.speak('a', locale: 'en'));
    unawaited(AgentSpeech.speak('b', locale: 'en'));
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(order, ['start-a', 'end-a', 'start-b', 'end-b']);
  });

  test('stop skips a queued utterance', () async {
    final started = <String>[];
    AgentSpeech.bind(
      synthesize: ({required text, required locale}) async {
        return const Left(NetworkFailure('use device'));
      },
    );
    DeviceTts.debugSpeakOverride = (text, {required locale}) async {
      started.add(text);
      await Future<void>.delayed(const Duration(milliseconds: 40));
    };

    final first = AgentSpeech.speak('a', locale: 'en');
    final second = AgentSpeech.speak('b', locale: 'en');
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await AgentSpeech.stop();
    await first;
    await second;

    expect(started.contains('b'), isFalse);
  });

  test('strips markdown before DeviceTts fallback', () async {
    final spoken = <String>[];
    AgentSpeech.bind(
      synthesize: ({required text, required locale}) async {
        return const Left(NetworkFailure('tts down'));
      },
    );
    DeviceTts.debugSpeakOverride = (text, {required locale}) async {
      spoken.add(text);
    };

    await AgentSpeech.speak('**500** for Mohamed', locale: 'en');
    expect(spoken, ['500 for Mohamed']);
  });

  test('skips UUID-only utterances', () async {
    var synthesized = 0;
    var spoken = 0;
    AgentSpeech.bind(
      synthesize: ({required text, required locale}) async {
        synthesized += 1;
        return const Left(NetworkFailure('unused'));
      },
    );
    DeviceTts.debugSpeakOverride = (text, {required locale}) async {
      spoken += 1;
    };

    await AgentSpeech.speak(
      '9135114a-bad1-4415-9ae6-ea4f8c66834f',
      locale: 'en',
    );
    expect(synthesized, 0);
    expect(spoken, 0);
  });

  test('coerces Latin text to en even when locale is ar', () async {
    final locales = <String>[];
    AgentSpeech.bind(
      synthesize: ({required text, required locale}) async {
        locales.add(locale);
        return const Left(NetworkFailure('use device'));
      },
    );
    DeviceTts.debugSpeakOverride = (text, {required locale}) async {};

    await AgentSpeech.speak('Mohamed owes 500', locale: 'ar');
    expect(locales, ['en']);
  });
}
