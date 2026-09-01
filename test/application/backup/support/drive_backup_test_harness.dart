import 'dart:io';

import 'package:daftar/application/backup/restore_backup_use_case.dart';
import 'package:daftar/application/backup/upload_drive_backup_use_case.dart';
import 'package:daftar/bootstrap.dart';
import 'package:daftar/data/datasources/local/drift_database.dart' as db;
import 'package:daftar/domain/repositories/auth_repository.dart';
import 'package:daftar/domain/repositories/backup_queue_repository.dart';
import 'package:daftar/domain/repositories/google_drive_backup_remote_repository.dart';
import 'package:daftar/domain/repositories/settings_repository.dart';
import 'package:daftar/presentation/providers/backup_providers.dart';
import 'package:daftar/presentation/providers/core_providers.dart';
import 'package:daftar/presentation/providers/storage_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'drive_backup_stubs.dart';

class FakePathProvider extends PathProviderPlatform {
  FakePathProvider(this.documentsPath);

  final String documentsPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;
}

class DriveBackupHarness {
  DriveBackupHarness({
    required this.container,
    required this.database,
    required this.documentsDirectory,
    required this.restorePathProvider,
  });

  final ProviderContainer container;
  final db.AppDatabase database;
  final Directory documentsDirectory;
  final void Function() restorePathProvider;

  Future<void> dispose() async {
    container.dispose();
    restorePathProvider();
    try {
      await database.close();
    } on Object {
      // The restore flow may already close the database connection.
    }
    if (documentsDirectory.existsSync()) {
      await documentsDirectory.delete(recursive: true);
    }
  }
}

Future<DriveBackupHarness> createDriveBackupHarness({
  required AuthRepository authRepository,
  required SettingsRepository settingsRepository,
  required MockGoogleAuthDs googleAuthDs,
  GoogleDriveBackupRemoteRepository? remoteRepository,
  BackupQueueRepository? backupQueueRepository,
  RestoreBackupUseCase? restoreBackupUseCase,
  UploadDriveBackupUseCase? uploadDriveBackupUseCase,
}) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  final documentsDirectory = await Directory.systemTemp.createTemp(
    'drive_backup_test_',
  );
  final previousPathProvider = PathProviderPlatform.instance;
  PathProviderPlatform.instance = FakePathProvider(documentsDirectory.path);

  final database = await openDatabase(documentsDirectory: documentsDirectory);

  final container = ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWith((ref) => database),
      appDocumentsDirectoryProvider.overrideWith(
        (ref) async => documentsDirectory,
      ),
      backupPublicExportEnabledProvider.overrideWith((ref) => false),
      authRepositoryProvider.overrideWith((ref) => authRepository),
      settingsRepositoryProvider.overrideWith((ref) => settingsRepository),
      googleAuthDsProvider.overrideWith((ref) => googleAuthDs),
      storageServiceProvider.overrideWith((ref) => FakeStorageService()),
      if (remoteRepository != null)
        googleDriveBackupRemoteRepositoryProvider.overrideWith(
          (ref) => remoteRepository,
        ),
      if (backupQueueRepository != null)
        backupQueueRepositoryProvider.overrideWith(
          (ref) => backupQueueRepository,
        ),
      if (restoreBackupUseCase != null)
        restoreBackupUseCaseProvider.overrideWith(
          (ref) => restoreBackupUseCase,
        ),
      if (uploadDriveBackupUseCase != null)
        uploadDriveBackupUseCaseProvider.overrideWith(
          (ref) => uploadDriveBackupUseCase,
        ),
    ],
  );

  return DriveBackupHarness(
    container: container,
    database: database,
    documentsDirectory: documentsDirectory,
    restorePathProvider: () {
      PathProviderPlatform.instance = previousPathProvider;
    },
  );
}
