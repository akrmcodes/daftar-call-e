import 'package:daftar/core/debug/agent_debug_log.dart';
import 'package:daftar/core/errors/exceptions.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/services/sync_token_store.dart';
import 'package:daftar/data/datasources/remote/edge_function_errors.dart';
import 'package:daftar/data/datasources/remote/google_auth_ds.dart';
import 'package:daftar/data/datasources/remote/supabase_auth_bridge_ds.dart';
import 'package:daftar/domain/entities/workspace_membership_snapshot.dart';
import 'package:daftar/domain/repositories/sync_auth_bridge_repository.dart';
import 'package:fpdart/fpdart.dart';

/// Data-layer Auth Bridge: Google ID token → sync JWT persistence.
class SyncAuthBridgeRepositoryImpl implements SyncAuthBridgeRepository {
  /// Creates the repository.
  SyncAuthBridgeRepositoryImpl({
    required GoogleAuthDs googleAuthDs,
    required SupabaseAuthBridgeDs bridgeDs,
    required SyncTokenStore syncTokenStore,
  })  : _googleAuthDs = googleAuthDs,
        _bridgeDs = bridgeDs,
        _syncTokenStore = syncTokenStore;

  final GoogleAuthDs _googleAuthDs;
  final SupabaseAuthBridgeDs _bridgeDs;
  final SyncTokenStore _syncTokenStore;

  @override
  Future<Either<Failure, SyncAuthCredentials>> ensureValid({
    bool allowInteractive = false,
  }) async {
    final cached = await _syncTokenStore.read();
    if (cached != null && cached.isValid) {
      return Right(_toCredentials(cached));
    }
    return exchange(allowInteractive: allowInteractive);
  }

  @override
  Future<Either<Failure, SyncAuthCredentials>> exchange({
    bool allowInteractive = false,
  }) async {
    try {
      final idToken = await _googleAuthDs.obtainIdToken(
        allowInteractive: allowInteractive,
      );
      if (idToken == null || idToken.isEmpty) {
        // #region agent log
        AgentDebugLog.write(
          location: 'sync_auth_bridge_repository_impl.dart:exchange',
          message: 'google_id_token_missing',
          hypothesisId: 'H4-google-token',
          data: <String, Object?>{
            'allowInteractive': allowInteractive,
          },
        );
        // #endregion
        return const Left(
          AuthFailure(
            'Google ID token unavailable for sync. Sign in again.',
            code: 'sync_id_token_missing',
          ),
        );
      }

      final bundle = await _bridgeDs.exchangeGoogleToken(idToken);
      return Right(_toCredentials(bundle));
    } on SyncAuthException catch (error) {
      return Left(AuthFailure(error.message, code: 'sync_auth_failed'));
    } on ServerException catch (error) {
      // #region agent log
      AgentDebugLog.write(
        location: 'sync_auth_bridge_repository_impl.dart:exchange',
        message: 'auth_bridge_server_exception',
        hypothesisId: 'H1-auth-bridge',
        data: <String, Object?>{
          'statusCode': error.statusCode,
          'errorCode': error.errorCode,
        },
      );
      // #endregion
      return Left(mapEdgeFunctionFailure(error, fallbackCode: 'sync_auth_failed'));
    } on Object catch (error) {
      return Left(
        NetworkFailure(
          'Auth bridge exchange failed: $error',
          code: 'sync_bridge_unexpected',
        ),
      );
    }
  }

  @override
  Future<WorkspaceMembershipSnapshot?> readLastKnownMembership() {
    return _syncTokenStore.readLastKnownMembership();
  }

  @override
  Future<Either<Failure, Unit>> clear() async {
    try {
      await _bridgeDs.clearToken();
      return const Right(unit);
    } on Object catch (error) {
      return Left(
        StorageFailure(
          'Failed to clear sync credentials: $error',
          code: 'sync_clear_failed',
        ),
      );
    }
  }

  static SyncAuthCredentials _toCredentials(SyncTokenBundle bundle) {
    return SyncAuthCredentials(
      syncToken: bundle.syncToken,
      workspaceId: bundle.workspaceId,
      role: bundle.role,
      obtainedAt: bundle.obtainedAt,
      expiresIn: bundle.expiresIn,
      identityHash: bundle.identityHash,
    );
  }
}
