import 'dart:io';

import 'package:daftar/bootstrap.dart';
import 'package:daftar/core/utils/app_restarter.dart';
import 'package:daftar/data/datasources/local/drift_database.dart' as db;
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Deletes the local SQLite files and optionally relaunches or reopens in-process.
abstract final class LocalDatabaseReset {
  /// Closes [databaseToClose], deletes on-disk SQLite files, and opens a fresh DB.
  static Future<db.AppDatabase> softWipeAndReopen({
    db.AppDatabase? databaseToClose,
  }) async {
    WidgetsFlutterBinding.ensureInitialized();

    if (databaseToClose != null) {
      try {
        await databaseToClose.close();
      } on Object {
        // Corrupt or already closed — continue with file deletion.
      }
    }

    await deleteDatabaseFiles();
    return openDatabase();
  }

  /// Removes `daftar.sqlite` (+ WAL/SHM/tmp) from the documents directory.
  static Future<void> deleteDatabaseFiles() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final databaseFile = File(
      p.join(documentsDirectory.path, 'daftar.sqlite'),
    );

    for (final path in <String>[
      databaseFile.path,
      '${databaseFile.path}-wal',
      '${databaseFile.path}-shm',
      '${databaseFile.path}.tmp',
    ]) {
      final file = File(path);
      if (file.existsSync()) {
        await file.delete();
      }
    }
  }

  /// Removes `daftar.sqlite` (+ WAL/SHM) and restarts the app.
  static Future<void> executeAndRestart({db.AppDatabase? databaseToClose}) async {
    WidgetsFlutterBinding.ensureInitialized();

    if (databaseToClose != null) {
      try {
        await databaseToClose.close();
      } on Object {
        // Corrupt or already closed — continue with file deletion.
      }
    }

    await deleteDatabaseFiles();
    await AppRestarter.restart();
  }
}
