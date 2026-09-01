import 'dart:typed_data';

import 'package:daftar/application/agent/synthesize_agent_speech_use_case.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/constants/closing_agent_constants.dart';
import 'package:daftar/domain/repositories/agent_speech_repository.dart';
import 'package:daftar/domain/value_objects/agent_speech_clip.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockAgentSpeechRepository extends Mock implements AgentSpeechRepository {}

void main() {
  late MockAgentSpeechRepository repository;
  late SynthesizeAgentSpeechUseCase useCase;

  setUp(() {
    repository = MockAgentSpeechRepository();
    useCase = SynthesizeAgentSpeechUseCase(repository: repository);
  });

  test(
    'empty text is ValidationFailure and does not hit the repository',
    () async {
      final result = await useCase.execute(text: '   ', locale: 'ar');
      expect(result.getLeft().toNullable(), isA<ValidationFailure>());
      expect(result.getLeft().toNullable()?.code, 'tts_text_required');
      verifyNever(
        () => repository.synthesize(
          text: any(named: 'text'),
          locale: any(named: 'locale'),
        ),
      );
    },
  );

  test('over cap is ValidationFailure', () async {
    final result = await useCase.execute(
      text: 'x' * (ClosingAgentConstants.maxTtsChars + 1),
      locale: 'en',
    );
    expect(result.getLeft().toNullable()?.code, 'tts_text_too_long');
    verifyNever(
      () => repository.synthesize(
        text: any(named: 'text'),
        locale: any(named: 'locale'),
      ),
    );
  });

  test('sanitizes markdown before hitting the repository', () async {
    final clip = AgentSpeechClip(
      bytes: Uint8List.fromList(const [1]),
    );
    when(
      () => repository.synthesize(text: 'Hello Mohamed', locale: 'en'),
    ).thenAnswer((_) async => Right(clip));

    final result = await useCase.execute(
      text: '**Hello** Mohamed',
      locale: 'en',
    );
    expect(result.getRight().toNullable(), clip);
  });

  test('UUID-only text is ValidationFailure', () async {
    final result = await useCase.execute(
      text: '9135114a-bad1-4415-9ae6-ea4f8c66834f',
      locale: 'en',
    );
    expect(result.getLeft().toNullable()?.code, 'tts_text_required');
    verifyNever(
      () => repository.synthesize(
        text: any(named: 'text'),
        locale: any(named: 'locale'),
      ),
    );
  });

  test('maps en-US to en and returns the clip', () async {
    final clip = AgentSpeechClip(
      bytes: Uint8List.fromList(const [1, 2]),
    );
    when(
      () => repository.synthesize(text: 'Hello', locale: 'en'),
    ).thenAnswer((_) async => Right(clip));

    final result = await useCase.execute(text: ' Hello ', locale: 'en-US');
    expect(result.getRight().toNullable(), clip);
  });

  test('maps Arabic locale to ar', () async {
    final clip = AgentSpeechClip(
      bytes: Uint8List.fromList(const [3]),
    );
    when(
      () => repository.synthesize(text: 'مرحبا', locale: 'ar'),
    ).thenAnswer((_) async => Right(clip));

    final result = await useCase.execute(text: 'مرحبا', locale: 'ar-SA');
    expect(result.getRight().toNullable(), clip);
  });

  test('coerces English locale to ar when the text is Arabic', () async {
    final clip = AgentSpeechClip(
      bytes: Uint8List.fromList(const [4]),
    );
    when(
      () => repository.synthesize(text: 'محمد عليه 500', locale: 'ar'),
    ).thenAnswer((_) async => Right(clip));

    final result = await useCase.execute(
      text: 'محمد عليه 500',
      locale: 'en',
    );
    expect(result.getRight().toNullable(), clip);
  });
}
