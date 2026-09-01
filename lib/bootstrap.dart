import 'dart:async';
import 'dart:io';
import 'dart:ui' show PlatformDispatcher;

import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/core/errors/database_corruption_exception.dart';
import 'package:daftar/core/services/database_integrity_service.dart';
import 'package:daftar/core/services/device_identity_store.dart';
import 'package:daftar/core/services/firebase_bootstrap.dart';
import 'package:daftar/core/services/global_error_handler.dart';
import 'package:daftar/core/utils/pdf_generator.dart';
import 'package:daftar/data/datasources/local/drift_database.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Opens (or re-opens) the Drift database from disk.
///
/// Extracted from [bootstrap] so it can be called independently during
/// the soft-restart flow after a backup restore, without repeating
/// one-time Flutter binding initialization.
Future<AppDatabase> openDatabase({Directory? documentsDirectory}) async {
  final resolvedDocumentsDirectory =
      documentsDirectory ?? await getApplicationDocumentsDirectory();
  final databaseFile = File(
    p.join(resolvedDocumentsDirectory.path, 'daftar.sqlite'),
  );

  AppDatabase? database;
  try {
    database = AppDatabase(
      NativeDatabase.createInBackground(databaseFile),
    );
    await DatabaseIntegrityService.assertOpen(database);
    return database;
  } on DatabaseCorruptionException {
    await database?.close();
    rethrow;
  } on Object catch (error) {
    await database?.close();
    if (DatabaseIntegrityService.isSqliteCorruptionError(error)) {
      throw DatabaseCorruptionException(cause: error);
    }
    rethrow;
  }
}

/// Initializes all app-level services before the UI is rendered.
///
/// This function runs before `runApp()` and sets up:
/// - Flutter binding initialization
/// - System UI chrome (status bar, nav bar)
/// - Firebase (fail-soft — never blocks ledger bootstrap)
/// - Global error handlers (Crashlytics when Firebase is live)
/// - Drift database
///
/// Called from `main()` in `lib/main.dart`.
Future<AppDatabase> bootstrap() async {
  // 1. Ensure Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();

  unawaited(PdfGenerator.preWarmFonts());

  // 2. Lock orientation to portrait (primary use case for merchants)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // 3. Match system chrome to native splash canvas on cold start
  final isDarkPlatform =
      PlatformDispatcher.instance.platformBrightness == Brightness.dark;
  final splashCanvas =
      isDarkPlatform ? AppColors.surface0 : AppColors.surface0Light;
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness:
          isDarkPlatform ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: splashCanvas,
      systemNavigationBarIconBrightness:
          isDarkPlatform ? Brightness.light : Brightness.dark,
    ),
  );

  // 4. Firebase initialization (fail-soft; offline-first if init fails)
  await FirebaseBootstrap.initialize();

  // 5. Global error handlers + premium fatal error surface
  //    (must run after Firebase so CrashLogger can reach Crashlytics)
  configureGlobalErrorHandling();

  // 6. Stable device identity (audit logs + merge engine tiebreaker)
  await DeviceIdentity.initialize(DeviceIdentityStore());

  // 7. Drift database initialization
  final database = await openDatabase();
  return database;
}
