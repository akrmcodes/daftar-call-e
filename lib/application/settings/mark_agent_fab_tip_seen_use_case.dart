import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/entities/app_settings.dart';
import 'package:daftar/domain/repositories/settings_repository.dart';
import 'package:fpdart/fpdart.dart';

/// Persists that the Closing Agent FAB coach has been shown.
class MarkAgentFabTipSeenUseCase {
  /// Creates the use case.
  const MarkAgentFabTipSeenUseCase(this._settingsRepository);

  final SettingsRepository _settingsRepository;

  /// Sets `hasSeenAgentFabTip`.
  Future<Either<Failure, AppSettings>> execute() {
    return _settingsRepository.update(
      const UpdateSettingsParams(hasSeenAgentFabTip: true),
    );
  }
}
