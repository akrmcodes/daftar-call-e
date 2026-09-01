import 'package:daftar/application/backup/ensure_drive_session.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/repositories/auth_repository.dart';
import 'package:daftar/domain/services/drive_session_gateway.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockDriveSessionGateway extends Mock implements DriveSessionGateway {}

void main() {
  late MockAuthRepository authRepository;
  late MockDriveSessionGateway driveSessionGateway;

  setUp(() {
    authRepository = MockAuthRepository();
    driveSessionGateway = MockDriveSessionGateway();
  });

  group('ensureHeadlessDriveSession', () {
    test('returns Right when gateway PKCE prerequisites pass', () async {
      when(() => driveSessionGateway.verifyHeadlessDrivePrerequisitesPkceOnly())
          .thenAnswer((_) async => const Right(unit));

      final result = await ensureHeadlessDriveSession(
        authRepository: authRepository,
        driveSessionGateway: driveSessionGateway,
      );

      expect(result.isRight(), isTrue);
      verify(() => driveSessionGateway.verifyHeadlessDrivePrerequisitesPkceOnly())
          .called(1);
      verifyNever(() => authRepository.signInSilently());
    });

    test('returns Left when gateway prerequisites fail', () async {
      when(() => driveSessionGateway.verifyHeadlessDrivePrerequisitesPkceOnly())
          .thenAnswer(
        (_) async => const Left(
          AuthFailure(
            'scopes missing',
            code: kDriveScopesNotAuthorizedCode,
          ),
        ),
      );

      final result = await ensureHeadlessDriveSession(
        authRepository: authRepository,
        driveSessionGateway: driveSessionGateway,
      );

      expect(result.isLeft(), isTrue);
      verifyNever(() => authRepository.signInSilently());
    });

    test('never calls interactive sign-in', () async {
      when(() => driveSessionGateway.verifyHeadlessDrivePrerequisitesPkceOnly())
          .thenAnswer((_) async => const Right(unit));

      await ensureHeadlessDriveSession(
        authRepository: authRepository,
        driveSessionGateway: driveSessionGateway,
      );

      verifyNever(() => authRepository.signInWithGoogle());
      verifyNever(() => authRepository.signInSilently());
    });

    test('propagates google_not_signed_in from gateway', () async {
      when(() => driveSessionGateway.verifyHeadlessDrivePrerequisitesPkceOnly())
          .thenAnswer(
        (_) async => const Left(
          AuthFailure('Token unavailable', code: 'google_not_signed_in'),
        ),
      );

      final result = await ensureHeadlessDriveSession(
        authRepository: authRepository,
        driveSessionGateway: driveSessionGateway,
      );

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure.code, 'google_not_signed_in'),
        (_) => fail('Expected Left'),
      );
    });
  });

  group('isTerminalBackgroundDriveAuthFailure', () {
    test('treats scope and silent failures as terminal', () {
      expect(
        isTerminalBackgroundDriveAuthFailure(
          const AuthFailure('', code: kDriveScopesNotAuthorizedCode),
        ),
        isTrue,
      );
      expect(
        isTerminalBackgroundDriveAuthFailure(
          const AuthFailure('', code: 'silent_sign_in_failed'),
        ),
        isTrue,
      );
      expect(
        isTerminalBackgroundDriveAuthFailure(
          const AuthFailure('', code: 'drive_auth_client_failed'),
        ),
        isTrue,
      );
    });

    test('treats network failures as non-terminal', () {
      expect(
        isTerminalBackgroundDriveAuthFailure(
          const NetworkFailure('offline', code: 'offline'),
        ),
        isFalse,
      );
    });
  });
}
