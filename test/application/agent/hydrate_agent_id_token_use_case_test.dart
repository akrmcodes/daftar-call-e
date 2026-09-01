import 'package:daftar/application/agent/hydrate_agent_id_token_use_case.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/repositories/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository authRepository;
  late HydrateAgentIdTokenUseCase useCase;

  setUp(() {
    authRepository = MockAuthRepository();
    useCase = HydrateAgentIdTokenUseCase(authRepository: authRepository);
  });

  test('requests PKCE hydrate for user-initiated Send', () async {
    when(
      () => authRepository.ensureLinkedIdToken(allowLightweightRestore: true),
    ).thenAnswer((_) async => const Right('hydrated-id-token'));

    final result = await useCase.execute();

    expect(result.getRight().toNullable(), 'hydrated-id-token');
    verify(
      () => authRepository.ensureLinkedIdToken(allowLightweightRestore: true),
    ).called(1);
  });

  test('forwards mismatch AuthFailure fail-closed', () async {
    const failure = AuthFailure(
      'Google account does not match the linked session.',
      code: 'agent_google_account_mismatch',
    );
    when(
      () => authRepository.ensureLinkedIdToken(allowLightweightRestore: true),
    ).thenAnswer((_) async => const Left(failure));

    final result = await useCase.execute();

    expect(result.getLeft().toNullable()?.code, 'agent_google_account_mismatch');
  });
}
