import 'dart:convert';
import 'dart:io';

import 'package:backup_notifier/backup_notifier.dart';
import 'package:daftar/data/services/backup_notification_client.dart';

/// Cross-isolate diagnostics ring buffer for auto-backup reliability.
abstract final class AutoBackupDiagnosticsLog {
  static BackupNotifier get _notifier =>
      BackupNotificationClient.instance.notifier;

  static Future<void> append({
    required String event,
    String source = 'dart',
  }) async {
    if (!Platform.isAndroid) {
      return;
    }
    await _notifier.appendDiagnostic(event: event, source: source);
  }

  static Future<List<AutoBackupDiagnosticEvent>> readAll() async {
    if (!Platform.isAndroid) {
      return const [];
    }
    final raw = await _notifier.readDiagnostics();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List<dynamic>) {
        return const [];
      }
      return decoded
          .whereType<Map<Object?, Object?>>()
          .map(
            (entry) => AutoBackupDiagnosticEvent(
              event: entry['event']?.toString() ?? '',
              source: entry['source']?.toString() ?? '',
              atMillis: (entry['at'] as num?)?.toInt() ?? 0,
            ),
          )
          .where((e) => e.event.isNotEmpty)
          .toList(growable: false);
    } on Object {
      return const [];
    }
  }

  static Future<void> clear() async {
    if (!Platform.isAndroid) {
      return;
    }
    await _notifier.clearDiagnostics();
  }
}

/// One diagnostic event from the native / Dart ring buffer.
final class AutoBackupDiagnosticEvent {
  const AutoBackupDiagnosticEvent({
    required this.event,
    required this.source,
    required this.atMillis,
  });

  final String event;
  final String source;
  final int atMillis;

  DateTime get at =>
      DateTime.fromMillisecondsSinceEpoch(atMillis, isUtc: true).toLocal();
}
