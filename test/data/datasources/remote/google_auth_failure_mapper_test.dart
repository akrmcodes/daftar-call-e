import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/data/datasources/remote/google_auth_exceptions.dart';
import 'package:daftar/data/datasources/remote/google_auth_failure_mapper.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';

void main() {
  group('GoogleAuthFailureMapper', () {
    test('maps canceled GoogleSignInException to canceled code', () {
      final failure = GoogleAuthFailureMapper.fromGoogleSignInException(
        const GoogleSignInException(
          code: GoogleSignInExceptionCode.canceled,
          description: 'User canceled',
        ),
      );

      expect(failure, isA<AuthFailure>());
      expect(failure.code, 'canceled');
    });

    test('maps userMismatch to google_account_mismatch code', () {
      final failure = GoogleAuthFailureMapper.fromGoogleSignInException(
        const GoogleSignInException(
          code: GoogleSignInExceptionCode.userMismatch,
        ),
      );

      expect(failure.code, 'google_account_mismatch');
    });

    test('maps configuration exception', () {
      final failure = GoogleAuthFailureMapper.fromConfigurationException(
        const GoogleAuthConfigurationException('missing client id'),
      );

      expect(failure.code, 'google_auth_configuration');
    });

    test('maps not signed in exception', () {
      final failure = GoogleAuthFailureMapper.fromNotSignedInException(
        const GoogleAuthNotSignedInException(),
      );

      expect(failure.code, 'google_not_signed_in');
    });

    test('maps timeout exception to google_auth_timeout code', () {
      final failure = GoogleAuthFailureMapper.fromTimeoutException(
        const GoogleAuthTimeoutException(),
      );

      expect(failure, isA<AuthFailure>());
      expect(failure.code, 'google_auth_timeout');
    });

    test('maps platform exception code', () {
      final failure = GoogleAuthFailureMapper.fromPlatformException(
        PlatformException(code: 'network_error', message: 'offline'),
      );

      expect(failure.code, 'network_error');
    });
  });
}
