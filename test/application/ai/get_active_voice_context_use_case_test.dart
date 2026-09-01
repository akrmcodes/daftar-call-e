import 'package:daftar/application/ai/get_active_voice_context_use_case.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/repositories/contact_repository.dart';
import 'package:daftar/domain/value_objects/voice_entity_resolution_entry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockContactRepository extends Mock implements ContactRepository {}

void main() {
  late MockContactRepository contactRepository;

  setUp(() {
    contactRepository = MockContactRepository();
  });

  group('GetActiveVoiceContextUseCase', () {
    test('delegates to repository', () async {
      final sut = GetActiveVoiceContextUseCase(contactRepository);
      const entries = [
        VoiceEntityResolutionEntry(
          contactId: 'c-1',
          contactName: 'Ali',
          ledgerId: 'l-1',
        ),
      ];
      when(() => contactRepository.getVoiceEntityResolutionContext()).thenAnswer(
        (_) async => const Right(entries),
      );

      final result = await sut.execute();

      expect(
        result,
        const Right<Failure, List<VoiceEntityResolutionEntry>>(entries),
      );
    });

    test('returns repository failure', () async {
      final sut = GetActiveVoiceContextUseCase(contactRepository);
      when(() => contactRepository.getVoiceEntityResolutionContext()).thenAnswer(
        (_) async => const Left(DatabaseFailure('voice context failed')),
      );

      final result = await sut.execute();

      expect(result.isLeft(), isTrue);
    });
  });
}
