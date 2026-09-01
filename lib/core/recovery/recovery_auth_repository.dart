import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/services/auth_session_store.dart';
import 'package:daftar/data/datasources/remote/auth_silent_sign_in_gateway_impl.dart';
import 'package:daftar/data/datasources/remote/google_auth_ds.dart';
import 'package:daftar/data/datasources/remote/google_auth_exceptions.dart';
import 'package:daftar/data/datasources/remote/google_auth_failure_mapper.dart';
import 'package:daftar/domain/entities/google_account_profile.dart';
import 'package:daftar/domain/enums/auth_session_state.dart';
import 'package:daftar/domain/repositories/auth_repository.dart';
import 'package:flutter/services.dart';
import 'package:fpdart/fpdart.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Minimal [AuthRepository] for Drive list/restore during DB recovery boot.
///
/// Reads the secure session bundle when present; does not write Drift or settings.
class RecoveryAuthRepository implements AuthRepository {
  RecoveryAuthRepository({
    required GoogleAuthDs googleAuthDs,
    required AuthSessionStore authSessionStore,
  })  : _googleAuthDs = googleAuthDs,
        _authSessionStore = authSessionStore,
        _silentSignInGateway = AuthSilentSignInGatewayImpl(googleAuthDs);

  /// Creates a recovery auth stack with a shared [AuthSessionStore].
  factory RecoveryAuthRepository.create() {
    final store = AuthSessionStore();
    final googleAuthDs = GoogleAuthDs(authSessionStore: store);
    return RecoveryAuthRepository(
      googleAuthDs: googleAuthDs,
      authSessionStore: store,
    );
  }

  final GoogleAuthDs _googleAuthDs;
  final AuthSessionStore _authSessionStore;
  final AuthSilentSignInGatewayImpl _silentSignInGateway;

  /// Shared Google auth + secure storage for Drive operations in recovery.
  (GoogleAuthDs googleAuthDs, AuthSessionStore authSessionStore) get stack =>
      (_googleAuthDs, _authSessionStore);

  @override
  Future<Either<Failure, Unit>> signInWithGoogle() => signInSilently();

  @override
  Future<Either<Failure, Unit>> signInSilently() async {
    try {
      await _googleAuthDs.ensureInitialized();

      final bundle = await _authSessionStore.read();
      if (bundle != null && bundle.hasValidCachedAccessToken) {
        return const Right(unit);
      }

      if (bundle != null) {
        final recovered = await _silentSignInGateway.attemptSilentRecovery(
          bundle,
        );
        if (recovered) {
          return const Right(unit);
        }
      }

      final account =
          await _googleAuthDs.signInSilently() ?? await _googleAuthDs.signIn();
      if (account == null) {
        return const Left(GoogleAuthFailureMapper.canceled);
      }
      return const Right(unit);
    } on PlatformException catch (error) {
      return Left(GoogleAuthFailureMapper.fromPlatformException(error));
    } on GoogleSignInException catch (error) {
      return Left(GoogleAuthFailureMapper.fromGoogleSignInException(error));
    } on GoogleAuthConfigurationException catch (error) {
      return Left(GoogleAuthFailureMapper.fromConfigurationException(error));
    } on Object catch (error) {
      return Left(AuthFailure('Google sign-in failed: $error'));
    }
  }

  @override
  Future<Either<Failure, Unit>> signOut() async => const Left(
        AuthFailure(
          'Sign out is unavailable during database recovery.',
          code: 'recovery_sign_out_unavailable',
        ),
      );

  @override
  Future<Either<Failure, String?>> getSignedInAccount() async {
    await _googleAuthDs.ensureInitialized();
    final bundle = await _authSessionStore.read();
    if (bundle != null) {
      return Right(bundle.googleUserId);
    }
    return Right(_googleAuthDs.getAccount()?.id);
  }

  @override
  Future<bool> isSignedIn() async {
    final bundle = await _authSessionStore.read();
    if (bundle != null) {
      return true;
    }
    await _googleAuthDs.ensureInitialized();
    return _googleAuthDs.getAccount() != null;
  }

  @override
  Future<Either<Failure, GoogleAccountProfile?>> getGoogleAccountProfile() async {
    await _googleAuthDs.ensureInitialized();
    final account = _googleAuthDs.getAccount();
    if (account != null) {
      return Right(
        GoogleAccountProfile(
          id: account.id,
          email: account.email,
          displayName: account.displayName,
          photoUrl: account.photoUrl,
        ),
      );
    }
    final bundle = await _authSessionStore.read();
    if (bundle != null) {
      return Right(
        GoogleAccountProfile(
          id: bundle.googleUserId,
          email: bundle.email,
          displayName: bundle.displayName,
          photoUrl: bundle.photoUrl,
        ),
      );
    }
    return const Right(null);
  }

  @override
  Future<AuthSessionState> getSessionState() async {
    if (await isSignedIn()) {
      return AuthSessionState.linked;
    }
    return AuthSessionState.unlinked;
  }

  @override
  Future<AuthSessionState> getSessionStateAfterInteractiveSignIn() =>
      getSessionState();

  @override
  Future<bool> hasDriveOfflineGrant() async {
    final bundle = await _authSessionStore.read();
    return bundle?.hasDriveOfflineGrant ?? false;
  }

  @override
  Future<Either<Failure, Unit>> completeDriveAuthorization() async =>
      const Left(
        AuthFailure(
          'Drive authorization is unavailable during database recovery.',
          code: kDriveOfflineGrantFailedCode,
        ),
      );

  @override
  Future<Either<Failure, String>> ensureLinkedIdToken({
    bool allowLightweightRestore = false,
  }) async {
    try {
      if (allowLightweightRestore) {
        final hydration = await _googleAuthDs.hydrateLinkedIdToken();
        return switch (hydration) {
          LinkedIdTokenReady(:final token) => Right(token),
          LinkedIdTokenMismatch() =>
            const Left(GoogleAuthFailureMapper.agentGoogleAccountMismatch),
          LinkedIdTokenNeedsOpenIdGrant() =>
            const Left(GoogleAuthFailureMapper.agentOpenIdGrantRequired),
          LinkedIdTokenMissing() =>
            const Left(GoogleAuthFailureMapper.agentIdTokenMissing),
        };
      }

      final token = await _googleAuthDs.obtainIdToken();
      if (token == null || token.isEmpty) {
        return const Left(GoogleAuthFailureMapper.agentIdTokenMissing);
      }
      return Right(token);
    } on PlatformException catch (error) {
      return Left(GoogleAuthFailureMapper.fromPlatformException(error));
    } on GoogleSignInException catch (error) {
      return Left(GoogleAuthFailureMapper.fromGoogleSignInException(error));
    } on GoogleAuthConfigurationException catch (error) {
      return Left(GoogleAuthFailureMapper.fromConfigurationException(error));
    } on GoogleAuthTimeoutException catch (error) {
      return Left(GoogleAuthFailureMapper.fromTimeoutException(error));
    } on Object catch (error) {
      return Left(
        AuthFailure(
          'Google ID token hydration failed: $error',
          code: 'agent_id_token_missing',
        ),
      );
    }
  }
}
