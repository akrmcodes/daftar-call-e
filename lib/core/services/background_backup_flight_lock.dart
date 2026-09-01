import 'package:daftar/core/utils/uuid_util.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cross-isolate single-flight lock for Drive encrypt+upload.
///
/// Workmanager headless isolates and the foreground UI share
/// [SharedPreferences], so a held lock prevents parallel
/// `files.create` uploads that produce duplicate Drive copies.
abstract final class BackgroundBackupFlightLock {
  static const _ownerKey = 'background_backup_flight_owner';
  static const _acquiredAtKey = 'background_backup_flight_acquired_at';

  /// Maximum time a lock may be held before it is considered stale.
  static const Duration ttl = Duration(minutes: 10);

  /// Attempts to acquire the lock. Returns an owner token on success, or
  /// `null` when another owner still holds a non-expired lock.
  static Future<String?> tryAcquire() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().toUtc();
    final existingOwner = prefs.getString(_ownerKey);
    final acquiredMillis = prefs.getInt(_acquiredAtKey);

    if (existingOwner != null &&
        existingOwner.isNotEmpty &&
        acquiredMillis != null) {
      final acquiredAt =
          DateTime.fromMillisecondsSinceEpoch(acquiredMillis, isUtc: true);
      if (now.difference(acquiredAt) < ttl) {
        return null;
      }
    }

    final owner = UuidUtil.generate();
    await prefs.setString(_ownerKey, owner);
    await prefs.setInt(_acquiredAtKey, now.millisecondsSinceEpoch);

    // Re-read to detect a lost race against another isolate.
    final confirmedOwner = prefs.getString(_ownerKey);
    if (confirmedOwner != owner) {
      return null;
    }
    return owner;
  }

  /// Releases the lock when [owner] still holds it.
  static Future<void> release(String owner) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_ownerKey) != owner) {
      return;
    }
    await prefs.remove(_ownerKey);
    await prefs.remove(_acquiredAtKey);
  }

  /// Whether a non-expired lock is currently held.
  static Future<bool> isHeld() async {
    final prefs = await SharedPreferences.getInstance();
    final existingOwner = prefs.getString(_ownerKey);
    final acquiredMillis = prefs.getInt(_acquiredAtKey);
    if (existingOwner == null ||
        existingOwner.isEmpty ||
        acquiredMillis == null) {
      return false;
    }
    final acquiredAt =
        DateTime.fromMillisecondsSinceEpoch(acquiredMillis, isUtc: true);
    return DateTime.now().toUtc().difference(acquiredAt) < ttl;
  }
}
