import 'package:daftar/application/auth/handle_google_account_change_use_case.dart';
import 'package:daftar/application/auth/reconcile_drift_identity_use_case.dart';
import 'package:daftar/application/auth/session_bootstrap_coordinator.dart';
import 'package:daftar/application/auto_backup/auto_backup_scheduler.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/services/auth_session_store.dart';
import 'package:daftar/core/utils/uuid_util.dart';
import 'package:daftar/data/datasources/local/audit_log_local_ds.dart';
import 'package:daftar/data/datasources/local/backup_local_ds.dart';
import 'package:daftar/data/datasources/local/backup_queue_local_ds.dart';
import 'package:daftar/data/datasources/remote/drive_offline_grant_ds.dart';
import 'package:daftar/data/datasources/remote/google_auth_ds.dart';
import 'package:daftar/data/datasources/remote/google_auth_exceptions.dart';
import 'package:daftar/data/datasources/remote/google_auth_failure_mapper.dart';
import 'package:daftar/data/datasources/remote/google_id_token_expiry.dart';
import 'package:daftar/data/datasources/remote/supabase_auth_bridge_ds.dart';
import 'package:daftar/data/models/audit_log_model.dart';
import 'package:daftar/data/repositories/repository_utils.dart';
import 'package:daftar/domain/constants/auth_scopes.dart';
import 'package:daftar/domain/constants/auth_session_constants.dart';
import 'package:daftar/domain/entities/google_account_profile.dart';
import 'package:daftar/domain/enums/auth_session_state.dart';
import 'package:daftar/domain/repositories/auth_repository.dart';
import 'package:daftar/domain/repositories/settings_repository.dart';
import 'package:daftar/domain/value_objects/auth_session_bundle.dart';
import 'package:flutter/services.dart';
import 'package:fpdart/fpdart.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Google-backed implementation of [AuthRepository] (Auth V2).
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required GoogleAuthDs googleAuthDs,
    required AuthSessionStore authSessionStore,
    required SettingsRepository settingsRepository,
    required ReconcileDriftIdentityUseCase reconcileDriftIdentityUseCase,
    required HandleGoogleAccountChangeUseCase handleGoogleAccountChangeUseCase,
    required SessionBootstrapCoordinator sessionBootstrapCoordinator,
    required BackupLocalDs backupLocalDs,
    required BackupQueueLocalDs backupQueueLocalDs,
    required AuditLogLocalDataSource auditLogLocalDataSource,
    DriveOfflineGrantDs? driveOfflineGrantDs,
    SupabaseAuthBridgeDs? supabaseAuthBridgeDs,
  })  : _googleAuthDs = googleAuthDs,
        _authSessionStore = authSessionStore,
        _settingsRepository = settingsRepository,
        _reconcileDriftIdentityUseCase = reconcileDriftIdentityUseCase,
        _handleGoogleAccountChangeUseCase = handleGoogleAccountChangeUseCase,
        _sessionBootstrapCoordinator = sessionBootstrapCoordinator,
        _backupLocalDs = backupLocalDs,
        _backupQueueLocalDs = backupQueueLocalDs,
        _auditLogLocalDataSource = auditLogLocalDataSource,
        _driveOfflineGrantDs = driveOfflineGrantDs,
        _supabaseAuthBridgeDs = supabaseAuthBridgeDs;

  final GoogleAuthDs _googleAuthDs;
  final DriveOfflineGrantDs? _driveOfflineGrantDs;
  final SupabaseAuthBridgeDs? _supabaseAuthBridgeDs;
  final AuthSessionStore _authSessionStore;
  final SettingsRepository _settingsRepository;
  final ReconcileDriftIdentityUseCase _reconcileDriftIdentityUseCase;
  final HandleGoogleAccountChangeUseCase _handleGoogleAccountChangeUseCase;
  final SessionBootstrapCoordinator _sessionBootstrapCoordinator;
  final BackupLocalDs _backupLocalDs;
  final BackupQueueLocalDs _backupQueueLocalDs;
  final AuditLogLocalDataSource _auditLogLocalDataSource;

  @override
  Future<Either<Failure, Unit>> signInWithGoogle() async {
    try {
      final oldBundle = await _authSessionStore.read();
      final settingsResult = await _settingsRepository.get();
      final existingSettings = settingsResult.fold((_) => null, (s) => s);

      final account = await _googleAuthDs.signIn();
      if (account == null) {
        return const Left(GoogleAuthFailureMapper.canceled);
      }

      return _finalizeGoogleSession(
        account: account,
        oldBundle: oldBundle,
        fallbackOldEmail: existingSettings?.googleAccountEmail,
        fallbackOldId: existingSettings?.googleAccountId,
      );
    } on PlatformException catch (error) {
      return Left(GoogleAuthFailureMapper.fromPlatformException(error));
    } on GoogleSignInException catch (error) {
      return Left(GoogleAuthFailureMapper.fromGoogleSignInException(error));
    } on GoogleAuthConfigurationException catch (error) {
      return Left(GoogleAuthFailureMapper.fromConfigurationException(error));
    } on GoogleAuthTimeoutException catch (error) {
      return Left(GoogleAuthFailureMapper.fromTimeoutException(error));
    } on Object catch (error) {
      return Left(AuthFailure('Google sign-in failed: $error'));
    }
  }

  @override
  Future<Either<Failure, Unit>> signInSilently() async {
    try {
      final oldBundle = await _authSessionStore.read();
      if (oldBundle != null && oldBundle.hasValidCachedAccessToken) {
        return const Right(unit);
      }

      if (oldBundle != null && oldBundle.hasDriveOfflineGrant) {
        final status = await _googleAuthDs.ensureDriveCredential();
        switch (status) {
          case DriveCredentialStatus.ready:
            return const Right(unit);
          case DriveCredentialStatus.revoked:
            return Left(
              GoogleAuthFailureMapper.fromGrantRevokedException(
                const GoogleDriveGrantRevokedException(),
              ),
            );
          case DriveCredentialStatus.unavailable:
            // Transient / offline — never fall through to GSI One Tap.
            return const Left(
              NetworkFailure(
                'Drive credentials temporarily unavailable.',
                code: 'network_unavailable',
              ),
            );
        }
      }

      // Linked without offline grant / expired token: do NOT open GSI UI.
      // User completes PKCE via the Drive authorization banner.
      if (oldBundle != null) {
        return const Left(GoogleAuthFailureMapper.silentSignInFailed);
      }

      final settingsResult = await _settingsRepository.get();
      final existingSettings = settingsResult.fold((_) => null, (s) => s);

      final account = await _googleAuthDs.signInSilently();
      if (account == null) {
        return const Left(AuthFailure.notSignedIn);
      }

      return _finalizeGoogleSession(
        account: account,
        oldBundle: oldBundle,
        fallbackOldEmail: existingSettings?.googleAccountEmail,
        fallbackOldId: existingSettings?.googleAccountId,
      );
    } on PlatformException catch (error) {
      return Left(GoogleAuthFailureMapper.fromPlatformException(error));
    } on GoogleSignInException catch (error) {
      return Left(GoogleAuthFailureMapper.fromGoogleSignInException(error));
    } on GoogleAuthConfigurationException catch (error) {
      return Left(GoogleAuthFailureMapper.fromConfigurationException(error));
    } on Object catch (error) {
      return Left(AuthFailure('Silent Google sign-in failed: $error'));
    }
  }

  @override
  Future<Either<Failure, Unit>> signOut() async {
    try {
      try {
        await _googleAuthDs.signOut();
      } on Object {
        // SDK sign-out failure must not block local cleanup.
        await _authSessionStore.delete();
      }

      await _supabaseAuthBridgeDs?.clearToken();

      final settingsResult = await _settingsRepository.update(
        const UpdateSettingsParams(clearGoogleAccount: true),
      );

      return await settingsResult.fold(
        (failure) async => Left(failure),
        (_) async {
          try {
            await _backupLocalDs.clearAllGoogleDriveFileIds();
            await _backupQueueLocalDs.clearAll();
            await AutoBackupScheduler.cancelAll();
            await _appendAuthAudit(action: 'SIGNED_OUT');
            _sessionBootstrapCoordinator.invalidate();
            return const Right(unit);
          } on Object catch (error) {
            return Left(
              DatabaseFailure(
                'Failed to clear Google Drive backup references: $error',
                code: 'clear_drive_file_ids',
              ),
            );
          }
        },
      );
    } on PlatformException catch (error) {
      return Left(GoogleAuthFailureMapper.fromPlatformException(error));
    } on GoogleSignInException catch (error) {
      return Left(GoogleAuthFailureMapper.fromGoogleSignInException(error));
    } on GoogleAuthConfigurationException catch (error) {
      return Left(GoogleAuthFailureMapper.fromConfigurationException(error));
    } on Object catch (error) {
      return Left(AuthFailure('Google sign-out failed: $error'));
    }
  }

  @override
  Future<Either<Failure, String?>> getSignedInAccount() async {
    try {
      final bundle = await _authSessionStore.read();
      return Right(bundle?.googleUserId);
    } on Object catch (error) {
      return Left(AuthFailure('Could not read signed-in account: $error'));
    }
  }

  @override
  Future<bool> isSignedIn() async {
    try {
      final bundle = await _authSessionStore.read();
      return bundle != null;
    } on Object {
      return false;
    }
  }

  @override
  Future<Either<Failure, GoogleAccountProfile?>> getGoogleAccountProfile() async {
    try {
      final bundle = await _authSessionStore.read();
      if (bundle == null) {
        return const Right(null);
      }

      final account = _googleAuthDs.getAccount();
      if (account != null && account.id == bundle.googleUserId) {
        return Right(
          GoogleAccountProfile(
            id: bundle.googleUserId,
            email: account.email.isNotEmpty ? account.email : bundle.email,
            displayName: account.displayName ?? bundle.displayName,
            photoUrl: account.photoUrl ?? bundle.photoUrl,
          ),
        );
      }

      return Right(
        GoogleAccountProfile(
          id: bundle.googleUserId,
          email: bundle.email,
          displayName: bundle.displayName,
          photoUrl: bundle.photoUrl,
        ),
      );
    } on GoogleAuthConfigurationException catch (error) {
      return Left(GoogleAuthFailureMapper.fromConfigurationException(error));
    } on Object catch (error) {
      return Left(AuthFailure('Could not read Google account: $error'));
    }
  }

  @override
  Future<AuthSessionState> getSessionState() async {
    final result = await _sessionBootstrapCoordinator.execute();
    return switch (result) {
      Right(value: final state) => state,
      Left() => _sessionStateWhenBootstrapFailed(),
    };
  }

  /// Fast path after interactive sign-in — avoids re-running silent bootstrap
  /// while the Google SDK session is still warm from [signInWithGoogle].
  @override
  Future<AuthSessionState> getSessionStateAfterInteractiveSignIn() async {
    final bundle = await _authSessionStore.read();
    if (bundle == null) {
      return AuthSessionState.unlinked;
    }

    final account = _googleAuthDs.getAccount();
    if (account != null && account.id == bundle.googleUserId) {
      final reconcileResult =
          await _reconcileDriftIdentityUseCase.execute(bundle);
      if (reconcileResult case Left()) {
        return AuthSessionState.needsReauth;
      }
      return AuthSessionState.linked;
    }

    return getSessionState();
  }

  Future<AuthSessionState> _sessionStateWhenBootstrapFailed() async {
    final bundle = await _authSessionStore.read();
    if (bundle != null) {
      return AuthSessionState.needsReauth;
    }
    return AuthSessionState.unlinked;
  }

  Future<Either<Failure, Unit>> _finalizeGoogleSession({
    required GoogleSignInAccount account,
    required AuthSessionBundle? oldBundle,
    required String? fallbackOldEmail,
    required String? fallbackOldId,
  }) async {
    final oldId = oldBundle?.googleUserId ?? fallbackOldId;
    final oldEmail = oldBundle?.email ?? fallbackOldEmail;
    if (_isExplicitAccountChange(oldId, account.id)) {
      final changeResult = await _handleGoogleAccountChangeUseCase(
        HandleGoogleAccountChangeParams(
          oldEmail: oldEmail,
          newEmail: account.email,
          newAccountId: account.id,
        ),
      );
      if (changeResult case Left(value: final failure)) {
        return Left(failure);
      }
    }

    // GSI-only link. Offline PKCE (AppAuth Custom Tab) is intentionally NOT
    // chained here — it opened a second Google UI after the account picker and,
    // with app-resume silent auth, stacked consent prompts in a loop.
    // Headless Workmanager users complete PKCE via [completeDriveAuthorization].
    await _googleAuthDs.persistSessionBundle(account);

    final bundle = await _authSessionStore.read();
    if (bundle == null) {
      return const Left(
        AuthFailure(
          'Google sign-in succeeded but session bundle was not persisted.',
          code: 'session_bundle_missing',
        ),
      );
    }

    final reconcileResult = await _reconcileDriftIdentityUseCase.execute(bundle);
    if (reconcileResult case Left(value: final failure)) {
      return Left(failure);
    }

    await _appendAuthAudit(
      action: 'LINKED',
      payload: encodePayload({
        'googleUserId': bundle.googleUserId,
        'email': bundle.email,
        'offlineGrant': bundle.hasDriveOfflineGrant,
      }),
    );

    _sessionBootstrapCoordinator.invalidate();
    return const Right(unit);
  }

  Future<bool> _runDriveOfflineGrantCeremony(String email) async {
    final grantDs = _driveOfflineGrantDs;
    if (grantDs == null) {
      return false;
    }
    final grant = await grantDs.acquire(loginHint: email);
    if (grant == null) {
      await _appendAuthAudit(action: 'OFFLINE_GRANT_ABSENT');
      return false;
    }
    await _authSessionStore.updateDriveOfflineGrant(
      refreshToken: grant.refreshToken,
      clientId: grant.clientId,
      scopesGranted: AuthScopes.pkceOfflineGrantScopes,
    );
    final accessToken = grant.accessToken;
    if (accessToken != null && accessToken.isNotEmpty) {
      await _authSessionStore.updateCachedAccessToken(
        accessToken,
        expiresAt: grant.accessTokenExpiresAt,
      );
    }
    final idToken = grant.idToken;
    if (idToken != null && idToken.isNotEmpty) {
      await _authSessionStore.updateCachedIdToken(
        idToken,
        expiresAt: googleIdTokenExpiry(idToken) ??
            DateTime.now().toUtc().add(AuthSessionConstants.cachedAccessTokenTtl),
      );
    }
    await _appendAuthAudit(action: 'OFFLINE_GRANT_LINKED');
    return true;
  }

  @override
  Future<bool> hasDriveOfflineGrant() async {
    try {
      final bundle = await _authSessionStore.read();
      return bundle?.hasDriveOfflineGrant ?? false;
    } on Object {
      return false;
    }
  }

  @override
  Future<Either<Failure, Unit>> completeDriveAuthorization() async {
    try {
      final bundle = await _authSessionStore.read();
      if (bundle == null) {
        return const Left(AuthFailure.notSignedIn);
      }
      if (bundle.hasOpenIdOfflineGrant) {
        return const Right(unit);
      }
      final granted = await _runDriveOfflineGrantCeremony(bundle.email);
      if (!granted) {
        return const Left(
          AuthFailure(
            'Google did not issue an offline Drive grant. Try again.',
            code: kDriveOfflineGrantFailedCode,
          ),
        );
      }
      return const Right(unit);
    } on GoogleAuthAppAuthException catch (error) {
      final action = error.code == 'appauth_user_cancelled'
          ? 'OFFLINE_GRANT_CANCELLED'
          : 'OFFLINE_GRANT_SKIPPED';
      await _appendAuthAudit(
        action: action,
        payload: encodePayload({'error': error.message, 'code': error.code}),
      );
      return Left(GoogleAuthFailureMapper.fromAppAuthException(error));
    } on GoogleAuthConfigurationException catch (error) {
      return Left(GoogleAuthFailureMapper.fromConfigurationException(error));
    } on GoogleAuthTimeoutException catch (error) {
      return Left(GoogleAuthFailureMapper.fromTimeoutException(error));
    } on Object catch (error) {
      await _appendAuthAudit(
        action: 'OFFLINE_GRANT_SKIPPED',
        payload: encodePayload({'error': '$error'}),
      );
      return Left(
        AuthFailure(
          'Drive authorization could not complete: $error',
          code: kDriveOfflineGrantFailedCode,
        ),
      );
    }
  }

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

  bool _isExplicitAccountChange(String? oldId, String newId) {
    if (oldId == null || oldId.trim().isEmpty) {
      return false;
    }
    return oldId != newId;
  }

  Future<void> _appendAuthAudit({
    required String action,
    String? payload,
  }) async {
    await _auditLogLocalDataSource.appendLog(
      AuditLogModel(
        id: UuidUtil.generate(),
        entityType: 'google_auth',
        entityId: 'google',
        action: action,
        payload: payload,
        timestamp: DateTime.now().toUtc(),
        deviceId: repositoryDeviceId,
      ),
    );
  }
}
