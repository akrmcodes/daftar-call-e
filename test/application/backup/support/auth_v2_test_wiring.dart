import 'dart:io';

import 'package:daftar/bootstrap.dart';
import 'package:daftar/core/constants/app_constants.dart';
import 'package:daftar/core/services/auth_session_store.dart';
import 'package:daftar/data/datasources/local/drift_database.dart' as db;
import 'package:daftar/data/datasources/remote/drive_offline_grant_ds.dart';
import 'package:daftar/data/datasources/remote/google_auth_ds.dart';
import 'package:daftar/domain/constants/auth_scopes.dart';
import 'package:daftar/domain/repositories/auth_repository.dart';
import 'package:daftar/domain/value_objects/auth_session_bundle.dart';
import 'package:daftar/presentation/providers/backup_providers.dart';
import 'package:daftar/presentation/providers/core_providers.dart';
import 'package:daftar/presentation/providers/storage_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'drive_backup_stubs.dart';
import 'drive_backup_test_harness.dart';
import 'fake_drive_backup_remote_repository.dart';

class StubDriveOfflineGrantDs extends DriveOfflineGrantDs {
  StubDriveOfflineGrantDs({this.grant});

  final DriveOfflineGrant? grant;

  @override
  Future<DriveOfflineGrant?> acquire({required String loginHint}) async {
    return grant ??
        (
          refreshToken: 'offline-refresh-token',
          clientId: 'android-client.apps.googleusercontent.com',
          accessToken: 'offline-access-token',
          accessTokenExpiresAt: DateTime.utc(2026, 7),
          idToken: null,
        );
  }
}

class IdentityDriftHarness {
  IdentityDriftHarness({
    required this.container,
    required this.database,
    required this.documentsDirectory,
    required this.googleAuthDs,
    required this.remoteRepository,
    required this.restorePathProvider,
  });

  final ProviderContainer container;
  final db.AppDatabase database;
  final Directory documentsDirectory;
  final MockGoogleAuthDs googleAuthDs;
  final FakeDriveBackupRemoteRepository remoteRepository;
  final void Function() restorePathProvider;

  AuthRepository get authRepository => container.read(authRepositoryProvider);

  AuthSessionStore get authSessionStore =>
      container.read(authSessionStoreProvider);

  Future<void> dispose() async {
    container.dispose();
    restorePathProvider();
    await database.close();
    if (documentsDirectory.existsSync()) {
      await documentsDirectory.delete(recursive: true);
    }
  }
}

/// Wires a full Auth V2 [ProviderContainer] for identity drift integration tests.
Future<IdentityDriftHarness> createIdentityDriftHarness({
  required Map<String, String> secureVault,
  FakeDriveBackupRemoteRepository? remoteRepository,
}) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  FlutterSecureStoragePlatform.instance =
      TestFlutterSecureStoragePlatform(secureVault);

  final documentsDirectory = await Directory.systemTemp.createTemp(
    'identity_drift_test_',
  );
  final previousPathProvider = PathProviderPlatform.instance;
  PathProviderPlatform.instance = FakePathProvider(documentsDirectory.path);

  final database = await openDatabase(documentsDirectory: documentsDirectory);
  final googleAuthDs = MockGoogleAuthDs();
  final fakeRemote = remoteRepository ?? FakeDriveBackupRemoteRepository();

  when(googleAuthDs.ensureInitialized).thenAnswer((_) async {});
  when(googleAuthDs.ensureDriveCredential).thenAnswer(
    (_) async => DriveCredentialStatus.ready,
  );
  when(googleAuthDs.getAuthenticatedHttpClient).thenThrow(
    StateError('HTTP client not required when remote repo is faked.'),
  );

  final container = ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWith((ref) => database),
      appDocumentsDirectoryProvider.overrideWith(
        (ref) async => documentsDirectory,
      ),
      backupPublicExportEnabledProvider.overrideWith((ref) => false),
      googleAuthDsProvider.overrideWith((ref) => googleAuthDs),
      googleDriveBackupRemoteRepositoryProvider.overrideWith(
        (ref) => fakeRemote,
      ),
      driveOfflineGrantDsProvider.overrideWith(
        (ref) => StubDriveOfflineGrantDs(),
      ),
      storageServiceProvider.overrideWith(
        (ref) => FakeStorageService(),
      ),
    ],
  );

  final authSessionStore = container.read(authSessionStoreProvider);
  when(() => googleAuthDs.persistSessionBundle(any())).thenAnswer(
    (invocation) async {
      final account = invocation.positionalArguments[0] as GoogleSignInAccount;
      await authSessionStore.write(
        AuthSessionBundle.create(
          googleUserId: account.id,
          email: account.email,
          displayName: account.displayName,
          photoUrl: account.photoUrl,
          serverClientId: 'test-server-client.apps.googleusercontent.com',
          scopesGranted: AuthScopes.defaultDriveBackupScopes,
          linkedAt: DateTime.now().toUtc(),
        ),
      );
    },
  );

  return IdentityDriftHarness(
    container: container,
    database: database,
    documentsDirectory: documentsDirectory,
    googleAuthDs: googleAuthDs,
    remoteRepository: fakeRemote,
    restorePathProvider: () {
      PathProviderPlatform.instance = previousPathProvider;
    },
  );
}

/// Writes [bundle] to secure storage and returns the persisted record.
Future<AuthSessionBundle> persistBundleInVault({
  required AuthSessionStore store,
  required AuthSessionBundle bundle,
}) async {
  await store.write(bundle);
  final read = await store.read();
  if (read == null) {
    throw StateError('Bundle was not persisted to secure vault.');
  }
  return read;
}

/// Confirms the secure vault contains a session bundle for [googleUserId].
Future<void> expectVaultBundleUserId({
  required Map<String, String> vault,
  required String googleUserId,
}) async {
  expect(vault.containsKey(AppConstants.authSessionStorageKey), isTrue);
  final store = AuthSessionStore(storage: const FlutterSecureStorage());
  final bundle = await store.read();
  expect(bundle?.googleUserId, googleUserId);
}
