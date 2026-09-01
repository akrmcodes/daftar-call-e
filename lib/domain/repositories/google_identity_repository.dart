import 'package:daftar/core/errors/failures.dart';
import 'package:fpdart/fpdart.dart';

/// Purges Google Drive–linked local state when the signed-in Google account changes.
///
/// Prevents uploading pending queues to the wrong Drive account and blocks
/// download attempts against file ids owned by a previous account.
abstract class GoogleIdentityRepository {
  /// Stales Google Drive backup metadata, clears the upload queue, and appends
  /// an audit entry describing the account switch.
  Future<Either<Failure, Unit>> purgeDriveIdentityOnAccountSwitch({
    required String? oldEmail,
    required String newEmail,
    required String newAccountId,
  });
}
