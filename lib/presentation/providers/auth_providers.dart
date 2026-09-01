import 'dart:async';

import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/services/pending_cloud_sync_store.dart';
import 'package:daftar/domain/entities/google_account_profile.dart';
import 'package:daftar/domain/enums/auth_session_state.dart';
import 'package:daftar/presentation/providers/backup_providers.dart';
import 'package:daftar/presentation/providers/core_providers.dart';
import 'package:daftar/presentation/providers/sync_auth_bridge_provider.dart';
import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_providers.g.dart';

/// Bundle-first Google session state (Auth V2).
///
/// Derives from secure-bundle session bootstrap — never from Drift
/// `googleAccountId` alone.
@Riverpod(keepAlive: true)
class AuthState extends _$AuthState {
  @override
  Future<AuthSessionState> build() async {
    return ref.watch(authRepositoryProvider).getSessionState();
  }

  /// Re-reads session state after interactive sign-in or sign-out.
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(
      await ref.read(authRepositoryProvider).getSessionState(),
    );
  }

  /// Forces a fresh bootstrap after auth mutations (bypasses coordinator cache).
  Future<void> refreshAfterAuthMutation() async {
    ref.read(sessionBootstrapCoordinatorProvider).invalidate();
    await refresh();
  }

  /// Re-reads session without an [AsyncLoading] flash.
  ///
  /// Used for silent resume / credential warm so screenshot and other
  /// inactive→resumed cycles do not rebuild the backup UI as "signed out".
  Future<void> reconcileQuietly() async {
    final next = await ref.read(authRepositoryProvider).getSessionState();
    if (!ref.mounted) {
      return;
    }
    if (state.asData?.value == next) {
      return;
    }
    state = AsyncData(next);
  }

  /// Sets session state after a successful interactive sign-in without
  /// re-running cold-start bootstrap against a still-warm SDK session.
  Future<void> adoptInteractiveSignIn() async {
    final repository = ref.read(authRepositoryProvider);
    state = AsyncData(
      await repository.getSessionStateAfterInteractiveSignIn(),
    );
  }
}

/// Google profile from the secure bundle when a linked identity exists.
///
/// Returns profile data for [AuthSessionState.linked] and
/// [AuthSessionState.needsReauth] (identity persists; Drive may need refresh).
@Riverpod(keepAlive: true)
Future<GoogleAccountProfile?> googleAccount(Ref ref) async {
  final session = await ref.watch(authStateProvider.future);
  if (session == AuthSessionState.unlinked) {
    return null;
  }

  final result =
      await ref.read(authRepositoryProvider).getGoogleAccountProfile();
  return result.fold(
    (_) => null,
    (profile) => profile,
  );
}

/// Whether the secure bundle holds the Drive offline grant (refresh token).
///
/// `false` for a linked session means headless backup will die when the
/// short-lived token expires — the backup screen surfaces a one-tap
/// completion action.
@Riverpod(keepAlive: true)
Future<bool> driveOfflineGrantReady(Ref ref) async {
  final session = await ref.watch(authStateProvider.future);
  if (session != AuthSessionState.linked) {
    return true;
  }
  return ref.read(authRepositoryProvider).hasDriveOfflineGrant();
}

/// Async controller for interactive Google sign-in and sign-out.
@Riverpod(keepAlive: true)
class SignInController extends _$SignInController {
  @override
  FutureOr<void> build() {}

  /// Starts interactive Google sign-in.
  Future<Either<Failure, Unit>> signInWithGoogle() async {
    state = const AsyncLoading();
    final result = await ref.read(authRepositoryProvider).signInWithGoogle();
    if (!ref.mounted) {
      return result.map((_) => unit);
    }
    if (result case Left(value: final failure)) {
      state = AsyncError(failure, StackTrace.current);
      return result;
    }

    await ref.read(authStateProvider.notifier).adoptInteractiveSignIn();
    if (!ref.mounted) {
      return const Right(unit);
    }

    _invalidateDriveBackupDependents();
    state = const AsyncData(null);
    return const Right(unit);
  }

  Future<Either<Failure, Unit>> signOut() async {
    state = const AsyncLoading();
    final result = await ref.read(authRepositoryProvider).signOut();
    if (!ref.mounted) {
      return result.map((_) => unit);
    }
    state = result.fold(
      (failure) => AsyncValue.error(failure, StackTrace.current),
      (_) => const AsyncValue.data(null),
    );
    if (result case Right()) {
      await ref.read(syncAuthBridgeProvider.notifier).clear();
      if (!ref.mounted) {
        return result;
      }
      await _sanitizeAuthDependentState();
      if (!ref.mounted) {
        return result;
      }
      await ref.read(authStateProvider.notifier).refreshAfterAuthMutation();
    }
    return result;
  }

  void _invalidateDriveBackupDependents() {
    ref
      ..invalidate(driveBackupProvider)
      ..invalidate(backupSyncStatusProvider)
      ..invalidate(googleDriveBackupRemoteRepositoryProvider)
      ..invalidate(googleAccountProvider)
      ..invalidate(driveOfflineGrantReadyProvider)
      ..invalidate(syncAuthBridgeProvider);
  }

  Future<void> _sanitizeAuthDependentState() async {
    await PendingCloudSyncStore.clear();
    _invalidateDriveBackupDependents();
    ref
      ..invalidate(googleAuthDsProvider)
      ..invalidate(authStateProvider);
  }
}

@Riverpod(keepAlive: true)
class DriveOfflineGrantController extends _$DriveOfflineGrantController {
  @override
  FutureOr<void> build() {}

  Future<Either<Failure, Unit>> completeDriveAuthorization() async {
    state = const AsyncLoading();
    final result =
        await ref.read(authRepositoryProvider).completeDriveAuthorization();
    state = result.fold(
      (failure) => AsyncValue.error(failure, StackTrace.current),
      (_) => const AsyncValue.data(null),
    );
    if (result case Right()) {
      ref.invalidate(driveOfflineGrantReadyProvider);
      unawaited(ref.read(driveBackupProvider.notifier).refreshRemoteList());
    }
    return result;
  }
}
