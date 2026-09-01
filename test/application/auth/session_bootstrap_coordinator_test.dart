import 'package:daftar/application/auth/session_bootstrap_coordinator.dart';
import 'package:daftar/application/auth/session_bootstrap_use_case.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/enums/auth_session_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockSessionBootstrapUseCase extends Mock
    implements SessionBootstrapUseCase {}

void main() {
  late MockSessionBootstrapUseCase useCase;
  late SessionBootstrapCoordinator coordinator;

  setUp(() {
    useCase = MockSessionBootstrapUseCase();
    coordinator = SessionBootstrapCoordinator(useCase);
  });

  test('execute runs use case only once for concurrent callers', () async {
    when(() => useCase.execute()).thenAnswer(
      (_) async => Future.delayed(
        const Duration(milliseconds: 50),
        () => const Right<Failure, AuthSessionState>(AuthSessionState.linked),
      ),
    );

    final results = await Future.wait([
      coordinator.execute(),
      coordinator.execute(),
      coordinator.execute(),
    ]);

    for (final result in results) {
      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('expected Right'),
        (state) => expect(state, AuthSessionState.linked),
      );
    }
    verify(() => useCase.execute()).called(1);
  });

  test('execute returns cached result on subsequent calls', () async {
    when(() => useCase.execute()).thenAnswer(
      (_) async =>
          const Right<Failure, AuthSessionState>(AuthSessionState.needsReauth),
    );

    await coordinator.execute();
    await coordinator.execute();

    verify(() => useCase.execute()).called(1);
  });

  test('invalidate forces a fresh bootstrap', () async {
    when(() => useCase.execute()).thenAnswer(
      (_) async =>
          const Right<Failure, AuthSessionState>(AuthSessionState.linked),
    );

    await coordinator.execute();
    coordinator.invalidate();
    await coordinator.execute();

    verify(() => useCase.execute()).called(2);
  });

  test('forceRefresh bypasses cache', () async {
    when(() => useCase.execute()).thenAnswer(
      (_) async =>
          const Right<Failure, AuthSessionState>(AuthSessionState.linked),
    );

    await coordinator.execute();
    await coordinator.execute(forceRefresh: true);

    verify(() => useCase.execute()).called(2);
  });

  test('propagates Left failures', () async {
    when(() => useCase.execute()).thenAnswer(
      (_) async =>
          const Left<Failure, AuthSessionState>(DatabaseFailure('db error')),
    );

    final result = await coordinator.execute();

    expect(result.isLeft(), isTrue);
    result.fold(
      (failure) => expect(failure, const DatabaseFailure('db error')),
      (_) => fail('expected Left'),
    );
  });
}
