import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight schedule bookkeeping for auto-backup catch-up (no heartbeat sprawl).
abstract final class AutoBackupScheduleStore {
  static const _nextScheduledAtKey = 'auto_backup_next_scheduled_at';
  static const _lastCompletedAtKey = 'auto_backup_last_completed_at';
  static const _lastSourceKey = 'auto_backup_last_source';

  static Future<void> recordScheduled({
    required DateTime nextScheduledAt,
    required String source,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _nextScheduledAtKey,
      nextScheduledAt.toUtc().toIso8601String(),
    );
    await prefs.setString(_lastSourceKey, source);
  }

  static Future<void> recordCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _lastCompletedAtKey,
      DateTime.now().toUtc().toIso8601String(),
    );
  }

  static Future<DateTime?> nextScheduledAt() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_nextScheduledAtKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw)?.toUtc();
  }

  /// True when next scheduled time is missing or older than [grace] ago.
  static Future<bool> isOverdue(Duration grace) async {
    final next = await nextScheduledAt();
    if (next == null) {
      return true;
    }
    final deadline = next.add(grace);
    return DateTime.now().toUtc().isAfter(deadline);
  }
}
