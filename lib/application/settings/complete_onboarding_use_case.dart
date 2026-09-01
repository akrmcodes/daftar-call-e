import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/entities/app_settings.dart';
import 'package:daftar/domain/repositories/settings_repository.dart';
import 'package:fpdart/fpdart.dart';

/// Persists first-run onboarding completion in application settings.
///
/// Returns the updated [AppSettings] on success or [DatabaseFailure] when
/// persistence fails.
class CompleteOnboardingUseCase {
  const CompleteOnboardingUseCase(this._settingsRepository);

  final SettingsRepository _settingsRepository;

  Future<Either<Failure, AppSettings>> call() {
    return _settingsRepository.update(
      const UpdateSettingsParams(hasSeenOnboarding: true),
    );
  }
}
