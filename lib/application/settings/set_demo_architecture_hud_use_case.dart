import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/entities/app_settings.dart';
import 'package:daftar/domain/repositories/settings_repository.dart';
import 'package:fpdart/fpdart.dart';

/// Persists the contest Architecture HUD overlay toggle.
class SetDemoArchitectureHudUseCase {
  /// Creates the use case.
  const SetDemoArchitectureHudUseCase(this._settingsRepository);

  final SettingsRepository _settingsRepository;

  /// Sets `demoArchitectureHud`.
  Future<Either<Failure, AppSettings>> execute({required bool enabled}) {
    return _settingsRepository.update(
      UpdateSettingsParams(demoArchitectureHud: enabled),
    );
  }
}
