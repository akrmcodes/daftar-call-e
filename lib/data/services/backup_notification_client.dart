import 'dart:io';

import 'package:backup_notifier/backup_notifier.dart';
import 'package:daftar/core/services/crash_logger_service.dart';
import 'package:daftar/domain/constants/backup_notification_ids.dart';
import 'package:daftar/domain/services/backup_notification_port.dart';

/// Android-native backup notifications via [BackupNotifier] plugin.
final class BackupNotificationClient implements BackupNotificationPort {
  BackupNotificationClient({BackupNotifier? notifier})
      : _notifier = notifier ?? BackupNotifier();

  /// Shared instance for headless Workmanager / FGS isolates.
  static final BackupNotificationClient instance = BackupNotificationClient();

  final BackupNotifier _notifier;

  BackupNotifier get notifier => _notifier;

  @override
  Future<void> ensureReady() async {
    if (!Platform.isAndroid) {
      return;
    }
    try {
      await _notifier.ensureReady();
    } on Object catch (error, stack) {
      await CrashLogger.recordError(
        error,
        stack,
        reason: 'BackupNotificationClient.ensureReady',
      );
    }
  }

  @override
  Future<void> show({
    required int id,
    required String channelId,
    required String title,
    required String body,
    bool ongoing = false,
    bool urgent = false,
  }) async {
    if (!Platform.isAndroid) {
      return;
    }
    try {
      final posted = await _notifier.show(
        id: id,
        channelId: channelId,
        title: title,
        body: body,
        ongoing: ongoing,
        urgent: urgent,
      );
      if (!posted) {
        await _notifier.appendDiagnostic(
          event: 'notif_blocked',
        );
      }
    } on Object catch (error, stack) {
      await CrashLogger.recordError(
        error,
        stack,
        reason: 'BackupNotificationClient.show',
      );
    }
  }

  @override
  Future<void> dismissInProgress() async {
    if (!Platform.isAndroid) {
      return;
    }
    try {
      await _notifier.cancel(id: BackupNotificationIds.inProgressNotificationId);
    } on Object catch (error, stack) {
      await CrashLogger.recordError(
        error,
        stack,
        reason: 'BackupNotificationClient.dismissInProgress',
      );
    }
  }
}
