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
  group('ensureDriveSession', () {
    test('delegates to auth repository silent sign-in', () async {
      final authRepository = MockAuthRepository();
      when(authRepository.signInSilently).thenAnswer(
        (_) async => const Right(unit),
      );

      final result = await ensureDriveSession(authRepository);

      expect(result, const Right<Failure, Unit>(unit));
    });
  });

  group('ensureHeadlessDriveSession', () {
    test('delegates to drive session gateway verification', () async {
      final authRepository = MockAuthRepository();
      final gateway = MockDriveSessionGateway();
      when(gateway.verifyHeadlessDrivePrerequisitesPkceOnly).thenAnswer(
        (_) async => const Right(unit),
      );

      final result = await ensureHeadlessDriveSession(
        authRepository: authRepository,
        driveSessionGateway: gateway,
      );

      expect(result, const Right<Failure, Unit>(unit));
    });
  });

  group('isDriveGrantRevokedFailure', () {
    test('returns true for refresh token revoked auth failure', () {
      const failure = AuthFailure(
        'revoked',
        code: kDriveRefreshTokenRevokedFailureCode,
      );

      expect(isDriveGrantRevokedFailure(failure), isTrue);
    });

    test('returns false for other failures', () {
      expect(isDriveGrantRevokedFailure(const NetworkFailure('offline')), isFalse);
    });
  });

  group('isTerminalBackgroundDriveAuthFailure', () {
    test('returns true for google_not_signed_in', () {
      expect(
        isTerminalBackgroundDriveAuthFailure(AuthFailure.notSignedIn),
        isTrue,
      );
    });

    test('returns true for drive scopes not authorized', () {
      expect(
        isTerminalBackgroundDriveAuthFailure(
          const AuthFailure('scopes', code: kDriveScopesNotAuthorizedCode),
        ),
        isTrue,
      );
    });

    test('returns false for network failures', () {
      expect(
        isTerminalBackgroundDriveAuthFailure(const NetworkFailure('offline')),
        isFalse,
      );
    });
  });
}
