import 'package:daftar/application/auto_backup/auto_backup_bootstrap.dart';
import 'package:daftar/application/auto_backup/auto_backup_ids.dart';
import 'package:daftar/application/auto_backup/auto_backup_runner.dart';
import 'package:daftar/core/services/crash_logger_service.dart';
import 'package:workmanager/workmanager.dart';

/// Top-level Workmanager entry point (official docs: must be top-level).
@pragma('vm:entry-point')
void autoBackupDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    await AutoBackupBootstrap.prime();
    switch (taskName) {
      case kAutoBackupRunTaskName:
        return AutoBackupRunner.runAutoBackup();
      case kAutoBackupQueueTaskName:
        return AutoBackupRunner.runQueueDrain();
      default:
        await CrashLogger.recordError(
          StateError('auto_backup_unknown_task: $taskName'),
          StackTrace.current,
          reason: 'auto_backup_unknown_task',
        );
        return true;
    }
  });
}
