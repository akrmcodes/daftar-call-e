import 'package:daftar/application/auto_backup/auto_backup_scheduler.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/services/auth_session_store.dart';
import 'package:daftar/domain/repositories/google_identity_repository.dart';
import 'package:fpdart/fpdart.dart';

/// Parameters for identity drift prevention when the Google account changes.
class HandleGoogleAccountChangeParams {
  const HandleGoogleAccountChangeParams({
    required this.oldEmail,
    required this.newEmail,
    required this.newAccountId,
  });

  final String? oldEmail;
  final String newEmail;
  final String newAccountId;
}

/// Atomic ceremony when [HandleGoogleAccountChangeParams] describes a switch
/// between Google accounts.
///
/// Order: cancel background sync → purge stale Drive metadata, upload queue,
/// and audit log → delete secure session bundle (only after purge succeeds).
///
/// The caller must persist the new session bundle **after** this use case
/// succeeds.
class HandleGoogleAccountChangeUseCase {
  const HandleGoogleAccountChangeUseCase(
    this._googleIdentityRepository,
    this._authSessionStore, {
    Future<void> Function()? cancelBackgroundSync,
  }) : _cancelBackgroundSync =
            cancelBackgroundSync ?? AutoBackupScheduler.cancelAll;

  final GoogleIdentityRepository _googleIdentityRepository;
  final AuthSessionStore _authSessionStore;
  final Future<void> Function() _cancelBackgroundSync;

  Future<Either<Failure, Unit>> call(
    HandleGoogleAccountChangeParams params,
  ) async {
    await _cancelBackgroundSync();

    final purgeResult =
        await _googleIdentityRepository.purgeDriveIdentityOnAccountSwitch(
      oldEmail: params.oldEmail,
      newEmail: params.newEmail,
      newAccountId: params.newAccountId,
    );
    if (purgeResult case Left(value: final failure)) {
      return Left(failure);
    }

    await _authSessionStore.delete();
    return const Right(unit);
  }
}
