import 'dart:io';

import 'package:daftar/bootstrap.dart';
import 'package:daftar/core/constants/app_constants.dart';
import 'package:daftar/core/env/env.dart';
import 'package:daftar/core/services/auth_session_store.dart';
import 'package:daftar/core/services/device_identity_store.dart';
import 'package:daftar/data/datasources/local/drift_database.dart' as db;
import 'package:daftar/data/datasources/remote/google_auth_ds.dart';
import 'package:daftar/domain/constants/auth_scopes.dart';
import 'package:daftar/domain/repositories/auth_repository.dart';
import 'package:daftar/domain/repositories/settings_repository.dart';
import 'package:daftar/domain/services/auth_silent_sign_in_gateway.dart';
import 'package:daftar/domain/value_objects/auth_session_bundle.dart';
import 'package:daftar/presentation/providers/backup_providers.dart';
import 'package:daftar/presentation/providers/core_providers.dart';
import 'package:daftar/presentation/providers/storage_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_v2_test_wiring.dart';
import 'drive_backup_stubs.dart';
import 'drive_backup_test_harness.dart';
import 'fake_drive_backup_remote_repository.dart';

/// Hermetic harness for Phase 7.3 Amnesia regression tests.
///
/// Simulates OS process kill by disposing in-memory [ProviderContainer] and
/// closing Drift while preserving secure vault + on-disk database files.
class AmnesiaRegressionHarness {
  AmnesiaRegressionHarness._({
    required this.vault,
    required this.documentsDirectory,
    required this.googleAuthDs,
    required this.restorePathProvider,
  });

  final Map<String, String> vault;
  final Directory documentsDirectory;
  final MockGoogleAuthDs googleAuthDs;
  final void Function() restorePathProvider;

  ProviderContainer? _container;
  db.AppDatabase? _database;

  ProviderContainer get container {
    final value = _container;
    if (value == null) {
      throw StateError('No active ProviderContainer — call bootForegroundContainer '
          'or bootColdStartContainer first.');
    }
    return value;
  }

  db.AppDatabase get database {
    final value = _database;
    if (value == null) {
      throw StateError('No active AppDatabase — call bootForegroundContainer '
          'or bootColdStartContainer first.');
    }
    return value;
  }

  AuthRepository get authRepository => container.read(authRepositoryProvider);

  AuthSessionStore get authSessionStore =>
      container.read(authSessionStoreProvider);

  SettingsRepository get settingsRepository =>
      container.read(settingsRepositoryProvider);

  static Future<AmnesiaRegressionHarness> create() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    DeviceIdentity.initializeForTest('amnesia-test-device');
    expect(Env.backupAesKey, isNotEmpty);
    SharedPreferences.setMockInitialValues({});

    final vault = <String, String>{};
    FlutterSecureStoragePlatform.instance =
        TestFlutterSecureStoragePlatform(vault);

    final documentsDirectory = await Directory.systemTemp.createTemp(
      'amnesia_regression_test_',
    );
    final previousPathProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = FakePathProvider(documentsDirectory.path);

    final googleAuthDs = MockGoogleAuthDs();
    when(googleAuthDs.ensureInitialized).thenAnswer((_) async {});
    when(googleAuthDs.ensureDriveCredential).thenAnswer(
      (_) async => DriveCredentialStatus.ready,
    );
    when(googleAuthDs.getAuthenticatedHttpClient).thenThrow(
      StateError('HTTP client not required when remote repo is faked.'),
    );

    return AmnesiaRegressionHarness._(
      vault: vault,
      documentsDirectory: documentsDirectory,
      googleAuthDs: googleAuthDs,
      restorePathProvider: () {
        PathProviderPlatform.instance = previousPathProvider;
      },
    );
  }

  Future<void> bootForegroundContainer({
    AuthSilentSignInGateway? silentSignInGateway,
    FakeDriveBackupRemoteRepository? remoteRepository,
  }) async {
    final database = await openDatabase(
      documentsDirectory: documentsDirectory,
    );
    _database = database;
    _container = _buildContainer(
      database: database,
      silentSignInGateway: silentSignInGateway,
      remoteRepository: remoteRepository,
    );
    _wirePersistSessionBundle();
  }

  Future<void> bootColdStartContainer({
    AuthSilentSignInGateway? silentSignInGateway,
    FakeDriveBackupRemoteRepository? remoteRepository,
  }) async {
    final database = await openDatabase(
      documentsDirectory: documentsDirectory,
    );
    _database = database;
    _container = _buildContainer(
      database: database,
      silentSignInGateway: silentSignInGateway,
      remoteRepository: remoteRepository,
    );
    _wirePersistSessionBundle();
  }

  /// Disposes in-memory state without clearing vault or deleting files.
  Future<void> simulateProcessKill() async {
    _container?.dispose();
    _container = null;
    await _database?.close();
    _database = null;
  }

  Future<void> disposeHarness() async {
    await simulateProcessKill();
    restorePathProvider();
    if (documentsDirectory.existsSync()) {
      await documentsDirectory.delete(recursive: true);
    }
  }

  Future<void> signInWithAccount(GoogleSignInAccount account) async {
    when(googleAuthDs.signIn).thenAnswer((_) async => account);
    when(googleAuthDs.signInSilently).thenAnswer((_) async => account);
    when(googleAuthDs.getAccount).thenReturn(account);
    when(googleAuthDs.isSignedIn).thenReturn(true);

    final result = await authRepository.signInWithGoogle();
    result.fold(
      (failure) => fail('signInWithGoogle failed: ${failure.message}'),
      (_) {},
    );
  }

  Future<void> enableAutoBackupInDrift({
    required String googleAccountId,
    required String googleAccountEmail,
  }) async {
    final result = await settingsRepository.update(
      UpdateSettingsParams(
        googleAccountId: googleAccountId,
        googleAccountEmail: googleAccountEmail,
        driveAutoBackupEnabled: true,
      ),
    );
    result.fold(
      (failure) => fail('enableAutoBackupInDrift failed: ${failure.message}'),
      (_) {},
    );
  }

  Future<void> writeBundleToVault(AuthSessionBundle bundle) async {
    await authSessionStore.write(bundle);
    expect(vault.containsKey(AppConstants.authSessionStorageKey), isTrue);
  }

  ProviderContainer _buildContainer({
    required db.AppDatabase database,
    AuthSilentSignInGateway? silentSignInGateway,
    FakeDriveBackupRemoteRepository? remoteRepository,
  }) {
    final fakeRemote = remoteRepository ?? FakeDriveBackupRemoteRepository();
    return ProviderContainer(
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
        storageServiceProvider.overrideWith((ref) => FakeStorageService()),
        if (silentSignInGateway != null)
          authSilentSignInGatewayProvider.overrideWith(
            (ref) => silentSignInGateway,
          ),
      ],
    );
  }

  void _wirePersistSessionBundle() {
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
  }
}

AuthSessionBundle sampleAmnesiaBundle({
  String googleUserId = 'google-sub-amnesia',
  String email = 'merchant@example.com',
}) =>
    AuthSessionBundle.create(
      googleUserId: googleUserId,
      email: email,
      displayName: 'Merchant',
      serverClientId: 'test-server-client.apps.googleusercontent.com',
      scopesGranted: AuthScopes.defaultDriveBackupScopes,
      linkedAt: DateTime.utc(2026, 6, 8, 12),
    );

AuthSessionBundle bundleWithHeadlessCredentials({
  String googleUserId = 'google-sub-amnesia',
  String email = 'merchant@example.com',
}) {
  return sampleAmnesiaBundle(googleUserId: googleUserId, email: email)
      .withCachedAccessToken(
        'headless-oauth-access-token',
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
      )
      .copyWith(
        driveRefreshToken: 'offline-refresh-token',
        driveTokenClientId: 'android-client.apps.googleusercontent.com',
      );
}
