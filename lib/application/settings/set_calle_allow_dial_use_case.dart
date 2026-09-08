import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/entities/app_settings.dart';
import 'package:daftar/domain/repositories/settings_repository.dart';
import 'package:fpdart/fpdart.dart';

/// Persists the merchant CALL-E outbound kill switch.
class SetCalleAllowDialUseCase {
  /// Creates the use case.
  const SetCalleAllowDialUseCase(this._settingsRepository);

  final SettingsRepository _settingsRepository;

  /// Sets `calleAllowDial`.
  Future<Either<Failure, AppSettings>> execute({required bool enabled}) {
    return _settingsRepository.update(
      UpdateSettingsParams(calleAllowDial: enabled),
    );
  }
}
