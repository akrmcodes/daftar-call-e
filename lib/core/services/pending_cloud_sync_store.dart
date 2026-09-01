import 'package:shared_preferences/shared_preferences.dart';

/// Persists a lightweight "cloud sync pending" hint across app restarts.
///
/// Complements the Drift drive backup queue table for UI and offline→online
/// resumption when the queue processor has not run yet.
abstract final class PendingCloudSyncStore {
  static const _prefKey = 'has_pending_cloud_sync';

  /// Returns whether a deferred Drive upload is flagged.
  static Future<bool> hasPending() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKey) ?? false;
  }

  /// Marks that cloud sync work should run when connectivity returns.
  static Future<void> setPending({required bool value}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, value);
  }

  /// Clears the pending flag after successful sync or empty queue.
  static Future<void> clear() => setPending(value: false);
}
