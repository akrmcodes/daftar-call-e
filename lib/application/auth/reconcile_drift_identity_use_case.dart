import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/repositories/settings_repository.dart';
import 'package:daftar/domain/value_objects/auth_session_bundle.dart';
import 'package:fpdart/fpdart.dart';

/// Synchronizes denormalized Drift Google identity fields from the secure bundle.
///
/// Drift `googleAccountId` / `googleAccountEmail` are UI hints only. The bundle
/// is authoritative — when values disagree, the bundle wins.
///
/// ## Business rules
/// - Called only after the session bundle is validated (SDK recovery succeeded).
/// - Never clears Google fields — sign-out flows own that ceremony.
/// - Idempotent when Drift already matches the bundle.
///
/// ## Non-goals (HARD RULE — Auth V2 Phase 1.4)
///
/// - NEVER store OAuth tokens in `SharedPreferences` — secure storage only.
/// - NEVER treat Drift `googleAccountId` alone as proof of signed-in state.
/// - NEVER swallow silent auth failures on cold start — emit `needsReauth`.
class ReconcileDriftIdentityUseCase {
  const ReconcileDriftIdentityUseCase(this._settingsRepository);

  final SettingsRepository _settingsRepository;

  /// Writes bundle identity to `AppSettings` when Drift is stale or empty.
  ///
  /// Returns [Right] when Drift matches or was updated successfully.
  /// Returns [Left] with [DatabaseFailure] when settings cannot be read/written.
  Future<Either<Failure, Unit>> execute(AuthSessionBundle bundle) async {
    final settingsResult = await _settingsRepository.get();
    if (settingsResult case Left(value: final failure)) {
      return Left(failure);
    }

    final settings = settingsResult.getRight().toNullable()!;
    if (settings.googleAccountId == bundle.googleUserId &&
        settings.googleAccountEmail == bundle.email) {
      return const Right(unit);
    }

    final updateResult = await _settingsRepository.update(
      UpdateSettingsParams(
        googleAccountId: bundle.googleUserId,
        googleAccountEmail: bundle.email,
      ),
    );

    return updateResult.map((_) => unit);
  }
}
