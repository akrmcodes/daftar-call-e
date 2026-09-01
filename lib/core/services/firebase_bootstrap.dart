import 'dart:developer' as developer;

import 'package:daftar/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Fail-soft Firebase initialization for offline-first bootstrap.
///
/// Never throws: ledger CRUD must remain usable if Firebase init fails
/// (roadmap §0.3.2.1).
abstract final class FirebaseBootstrap {
  /// Initializes Firebase and enables Crashlytics collection when possible.
  ///
  /// Returns `true` when [Firebase.initializeApp] succeeded.
  static Future<bool> initialize() async {
    if (kIsWeb) {
      return false;
    }

    try {
      if (Firebase.apps.isNotEmpty) {
        await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
          true,
        );
        return true;
      }

      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
      if (kDebugMode) {
        debugPrint('FirebaseBootstrap: initialized successfully');
      }
      return true;
    } on Object catch (error, stackTrace) {
      developer.log(
        'FirebaseBootstrap.initialize failed — continuing offline-first',
        error: error,
        stackTrace: stackTrace,
        name: 'daftar.firebase',
      );
      if (kDebugMode) {
        debugPrint('FirebaseBootstrap unavailable: $error');
      }
      return false;
    }
  }
}
