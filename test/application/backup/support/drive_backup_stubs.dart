import 'package:daftar/core/constants/app_constants.dart';
import 'package:daftar/core/services/storage_service.dart';
import 'package:daftar/data/datasources/remote/google_auth_ds.dart';
import 'package:daftar/domain/entities/app_settings.dart';
import 'package:daftar/domain/entities/backup_queue_item.dart';
import 'package:daftar/domain/repositories/auth_repository.dart';
import 'package:daftar/domain/repositories/backup_queue_repository.dart';
import 'package:daftar/domain/repositories/settings_repository.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockSettingsRepository extends Mock implements SettingsRepository {}

class MockBackupQueueRepository extends Mock implements BackupQueueRepository {}

class MockGoogleAuthDs extends Mock implements GoogleAuthDs {}

const defaultDriveBackupSettings = AppSettings(
  googleAccountId: 'google-user-1',
  googleAccountEmail: 'merchant@example.com',
);

void stubSignedInAuth(MockAuthRepository authRepository) {
  when(() => authRepository.signInWithGoogle()).thenAnswer(
    (_) async => const Right(unit),
  );
  when(() => authRepository.signOut()).thenAnswer(
    (_) async => const Right(unit),
  );
  when(() => authRepository.getSignedInAccount()).thenAnswer(
    (_) async => const Right(null),
  );
  when(() => authRepository.isSignedIn()).thenAnswer((_) async => false);
  when(() => authRepository.signInSilently()).thenAnswer(
    (_) async => const Right(unit),
  );
  when(() => authRepository.getGoogleAccountProfile()).thenAnswer(
    (_) async => const Right(null),
  );
}

void stubSettingsRepository(
  MockSettingsRepository settingsRepository, {
  AppSettings settings = defaultDriveBackupSettings,
}) {
  when(() => settingsRepository.get()).thenAnswer(
    (_) async => Right(settings),
  );
  when(() => settingsRepository.update(any())).thenAnswer(
    (_) async => Right(settings),
  );
  when(() => settingsRepository.watchSettings()).thenAnswer(
    (_) => Stream.value(settings),
  );
}

void stubGoogleAuthDs(MockGoogleAuthDs googleAuthDs) {
  when(() => googleAuthDs.ensureInitialized()).thenAnswer((_) async {});
  when(() => googleAuthDs.getAuthenticatedHttpClient()).thenThrow(
    StateError('Unexpected request for an authenticated Google client.'),
  );
}

void stubQueueRepository(MockBackupQueueRepository queueRepository) {
  when(
    () => queueRepository.getPendingRetryable(),
  ).thenAnswer((_) async => const <BackupQueueItem>[]);
  when(() => queueRepository.insertItem(any())).thenAnswer((_) async {});
  when(() => queueRepository.updateItem(any())).thenAnswer((_) async {});
  when(() => queueRepository.deleteItem(any())).thenAnswer((_) async {});
  when(() => queueRepository.anyNeedsReauth()).thenAnswer((_) async => false);
}

/// Skips platform disk-space probes so integration tests stay hermetic.
class FakeStorageService extends StorageService {
  @override
  Future<bool> hasEnoughSpace({
    int minMegabytes = AppConstants.minFreeStorageMegabytes,
  }) async {
    return true;
  }
}
