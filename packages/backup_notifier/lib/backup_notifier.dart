import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Native Android backup notification + Doze-piercing alarm bridge.
///
/// Works in the main isolate and Workmanager / FGS background isolates when
/// `DartPluginRegistrant.ensureInitialized` has run.
class BackupNotifier {
  BackupNotifier({@visibleForTesting MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('daftar/backup_notifier');

  final MethodChannel _channel;

  /// Ensures notification channels exist on Android.
  Future<void> ensureReady() async {
    if (kIsWeb) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('ensureReady');
    } on MissingPluginException {
      // Non-Android or plugin not linked.
    }
  }

  /// Whether the OS currently allows posting notifications.
  Future<bool> areNotificationsEnabled() async {
    if (kIsWeb) {
      return true;
    }
    try {
      final enabled =
          await _channel.invokeMethod<bool>('areNotificationsEnabled');
      return enabled ?? true;
    } on MissingPluginException {
      return true;
    }
  }

  /// Posts a local notification via Android `NotificationManager`.
  ///
  /// Returns `true` when the notification was posted.
  Future<bool> show({
    required int id,
    required String channelId,
    required String title,
    required String body,
    bool ongoing = false,
    bool urgent = false,
  }) async {
    if (kIsWeb) {
      return false;
    }
    try {
      final result = await _channel.invokeMethod<Object?>(
        'showNotification',
        <String, Object?>{
          'id': id,
          'channelId': channelId,
          'title': title,
          'body': body,
          'ongoing': ongoing,
          'urgent': urgent,
        },
      );
      if (result is Map) {
        return result['posted'] == true;
      }
      return true;
    } on MissingPluginException {
      return false;
    }
  }

  /// Cancels a notification by id.
  Future<void> cancel({required int id}) async {
    if (kIsWeb) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('cancelNotification', <String, Object?>{
        'id': id,
      });
    } on MissingPluginException {
      // Non-Android or plugin not linked.
    }
  }

  /// Schedules a Doze-piercing AlarmManager trigger.
  Future<Map<String, Object?>> scheduleAutoBackupAlarm({
    required int triggerAtMillis,
    required int intervalMillis,
    required int callbackHandle,
    String locale = 'ar',
  }) async {
    if (kIsWeb) {
      return const <String, Object?>{};
    }
    try {
      final result = await _channel.invokeMethod<Object?>(
        'scheduleAutoBackupAlarm',
        <String, Object?>{
          'triggerAtMillis': triggerAtMillis,
          'intervalMillis': intervalMillis,
          'callbackHandle': callbackHandle,
          'locale': locale,
        },
      );
      if (result is Map) {
        return Map<String, Object?>.from(result);
      }
      return const <String, Object?>{};
    } on MissingPluginException {
      return const <String, Object?>{};
    }
  }

  /// Cancels the Doze-piercing auto-backup alarm.
  Future<void> cancelAutoBackupAlarm() async {
    if (kIsWeb) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('cancelAutoBackupAlarm');
    } on MissingPluginException {
      // Non-Android or plugin not linked.
    }
  }

  /// Whether `SCHEDULE_EXACT_ALARM` is currently granted (API 31+).
  Future<bool> canScheduleExactAlarms() async {
    if (kIsWeb) {
      return true;
    }
    try {
      final value =
          await _channel.invokeMethod<bool>('canScheduleExactAlarms');
      return value ?? true;
    } on MissingPluginException {
      return true;
    }
  }

  /// Opens the system exact-alarm settings page (API 31+).
  Future<bool> openExactAlarmSettings() async {
    if (kIsWeb) {
      return false;
    }
    try {
      final opened =
          await _channel.invokeMethod<bool>('openExactAlarmSettings');
      return opened ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Snapshot of the native alarm bookkeeping.
  Future<Map<String, Object?>> getAlarmState() async {
    if (kIsWeb) {
      return const <String, Object?>{};
    }
    try {
      final result = await _channel.invokeMethod<Object?>('getAlarmState');
      if (result is Map) {
        return Map<String, Object?>.from(result);
      }
      return const <String, Object?>{};
    } on MissingPluginException {
      return const <String, Object?>{};
    }
  }

  /// Reads the native diagnostics ring buffer as a JSON array string.
  Future<String> readDiagnostics() async {
    if (kIsWeb) {
      return '[]';
    }
    try {
      final raw = await _channel.invokeMethod<String>('readDiagnostics');
      return raw ?? '[]';
    } on MissingPluginException {
      return '[]';
    }
  }

  /// Clears the native diagnostics ring buffer.
  Future<void> clearDiagnostics() async {
    if (kIsWeb) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('clearDiagnostics');
    } on MissingPluginException {
      // Non-Android or plugin not linked.
    }
  }

  /// Appends a diagnostic event from Dart.
  Future<void> appendDiagnostic({
    required String event,
    String source = 'dart',
  }) async {
    if (kIsWeb) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('appendDiagnostic', <String, Object?>{
        'event': event,
        'source': source,
      });
    } on MissingPluginException {
      // Non-Android or plugin not linked.
    }
  }
}
