import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/data/datasources/remote/google_auth_exceptions.dart';
import 'package:daftar/domain/repositories/auth_repository.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Maps Google Sign-In transport and configuration errors to [AuthFailure].
abstract final class GoogleAuthFailureMapper {
  static AuthFailure fromPlatformException(PlatformException exception) {
    final message = exception.message ?? exception.code;
    return AuthFailure(message, code: exception.code);
  }

  static AuthFailure fromGoogleSignInException(GoogleSignInException exception) {
    final description = exception.description;
    switch (exception.code) {
      case GoogleSignInExceptionCode.clientConfigurationError:
      case GoogleSignInExceptionCode.providerConfigurationError:
        return AuthFailure(
          description ?? 'Google Sign-In is not configured correctly.',
          code: exception.code.name,
        );
      case GoogleSignInExceptionCode.canceled:
        return AuthFailure(
          description ?? 'Sign-in was canceled.',
          code: 'canceled',
        );
      case GoogleSignInExceptionCode.interrupted:
      case GoogleSignInExceptionCode.uiUnavailable:
        return AuthFailure(
          description ?? 'Sign-in could not complete.',
          code: exception.code.name,
        );
      case GoogleSignInExceptionCode.userMismatch:
        return AuthFailure(
          description ?? 'Google account mismatch.',
          code: 'google_account_mismatch',
        );
      case GoogleSignInExceptionCode.unknownError:
        return AuthFailure(
          description ?? 'Unknown Google Sign-In error.',
          code: exception.code.name,
        );
    }
  }

  static AuthFailure fromConfigurationException(
    GoogleAuthConfigurationException exception,
  ) {
    return AuthFailure(exception.message, code: 'google_auth_configuration');
  }

  static AuthFailure fromAppAuthException(GoogleAuthAppAuthException exception) {
    return AuthFailure(exception.message, code: exception.code);
  }

  static AuthFailure fromTimeoutException(
    GoogleAuthTimeoutException exception,
  ) {
    return AuthFailure(exception.message, code: 'google_auth_timeout');
  }

  static AuthFailure fromGrantRevokedException(
    GoogleDriveGrantRevokedException exception,
  ) {
    return AuthFailure(exception.message, code: kDriveRefreshTokenRevokedCode);
  }

  /// Machine-readable code: the stored refresh token was revoked server-side.
  static const String kDriveRefreshTokenRevokedCode =
      'drive_refresh_token_revoked';

  static AuthFailure fromNotSignedInException(
    GoogleAuthNotSignedInException exception,
  ) {
    return AuthFailure(exception.message, code: 'google_not_signed_in');
  }

  static const AuthFailure canceled = AuthFailure(
    'Google sign-in was canceled.',
    code: 'canceled',
  );

  static const AuthFailure silentSignInFailed = AuthFailure(
    'Silent Google sign-in did not restore a session.',
    code: 'silent_sign_in_failed',
  );

  /// Linked session has no usable Google ID token (agent / Cloud Run).
  static const AuthFailure agentIdTokenMissing = AuthFailure(
    'Google ID token unavailable for Closing Agent.',
    code: 'agent_id_token_missing',
  );

  /// Lightweight restore returned a different Google user than the bundle.
  static const AuthFailure agentGoogleAccountMismatch = AuthFailure(
    'Google account does not match the linked session.',
    code: 'agent_google_account_mismatch',
  );

  /// Drive PKCE grant lacks `openid` — one-time AppAuth re-consent required.
  static const AuthFailure agentOpenIdGrantRequired = AuthFailure(
    'Google identity grant must be updated once to keep the agent signed in.',
    code: kAgentOpenIdGrantRequiredCode,
  );
}
