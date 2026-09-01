package com.akrmcodes.daftar.backup_notifier

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.SystemClock
import android.util.Log

/**
 * Schedules Doze-piercing alarms for automatic Drive backup.
 *
 * Prefers [AlarmManager.setExactAndAllowWhileIdle] when exact-alarm permission
 * is granted; otherwise falls back to [AlarmManager.setAndAllowWhileIdle]
 * (no special permission required, still fires in Doze).
 */
object AutoBackupAlarmScheduler {
	private const val TAG = "DaftarAutoBackup"
	private const val PREFS = "daftar_auto_backup_alarm"
	private const val KEY_NEXT_TRIGGER_AT = "next_trigger_at_millis"
	private const val KEY_INTERVAL_MILLIS = "interval_millis"
	private const val KEY_ENABLED = "enabled"
	private const val KEY_CALLBACK_HANDLE = "callback_handle"
	private const val KEY_LOCALE = "locale"
	private const val REQUEST_CODE = 0x00ABAC11
	private const val MIN_INTERVAL_MILLIS = 15L * 60L * 1000L
	private const val DEFAULT_INTERVAL_MILLIS = 24L * 60L * 60L * 1000L
	private const val DEFAULT_LOCALE = "ar"

	fun schedule(
		context: Context,
		triggerAtMillis: Long,
		intervalMillis: Long,
		callbackHandle: Long,
		locale: String = DEFAULT_LOCALE,
	) {
		val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
		val safeInterval = intervalMillis.coerceAtLeast(MIN_INTERVAL_MILLIS)
		val safeTrigger = triggerAtMillis.coerceAtLeast(System.currentTimeMillis() + 5_000L)
		val safeLocale = normalizeLocale(locale)

		prefs.edit()
			.putBoolean(KEY_ENABLED, true)
			.putLong(KEY_NEXT_TRIGGER_AT, safeTrigger)
			.putLong(KEY_INTERVAL_MILLIS, safeInterval)
			.putLong(KEY_CALLBACK_HANDLE, callbackHandle)
			.putString(KEY_LOCALE, safeLocale)
			.apply()

		armAlarm(context, safeTrigger)
		Log.i(TAG, "Armed auto-backup alarm at $safeTrigger (interval=$safeInterval locale=$safeLocale)")
	}

	fun cancel(context: Context) {
		val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
		prefs.edit()
			.putBoolean(KEY_ENABLED, false)
			.remove(KEY_NEXT_TRIGGER_AT)
			.apply()

		val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
		alarmManager.cancel(pendingIntent(context))
		Log.i(TAG, "Cancelled auto-backup alarm")
	}

	/** Re-arms from persisted state (boot / package replace / time change). */
	fun rearmFromPrefs(context: Context) {
		val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
		if (!prefs.getBoolean(KEY_ENABLED, false)) {
			return
		}
		val interval = prefs.getLong(KEY_INTERVAL_MILLIS, DEFAULT_INTERVAL_MILLIS)
			.coerceAtLeast(MIN_INTERVAL_MILLIS)
		val stored = prefs.getLong(KEY_NEXT_TRIGGER_AT, 0L)
		val now = System.currentTimeMillis()
		val trigger = when {
			stored <= 0L -> now + 60_000L
			stored <= now -> now + 15_000L
			else -> stored
		}
		prefs.edit().putLong(KEY_NEXT_TRIGGER_AT, trigger).apply()
		armAlarm(context, trigger)
		Log.i(TAG, "Re-armed auto-backup alarm at $trigger (interval=$interval)")
	}

	/** Called after an alarm fires to schedule the next interval. */
	fun scheduleNextFromPrefs(context: Context) {
		val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
		if (!prefs.getBoolean(KEY_ENABLED, false)) {
			return
		}
		val interval = prefs.getLong(KEY_INTERVAL_MILLIS, DEFAULT_INTERVAL_MILLIS)
			.coerceAtLeast(MIN_INTERVAL_MILLIS)
		val callbackHandle = prefs.getLong(KEY_CALLBACK_HANDLE, 0L)
		val locale = prefs.getString(KEY_LOCALE, DEFAULT_LOCALE) ?: DEFAULT_LOCALE
		val next = System.currentTimeMillis() + interval
		schedule(context, next, interval, callbackHandle, locale)
	}

	fun canScheduleExactAlarms(context: Context): Boolean {
		if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
			return true
		}
		val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
		return alarmManager.canScheduleExactAlarms()
	}

	fun openExactAlarmSettings(context: Context): Boolean {
		if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
			return false
		}
		return try {
			val intent = Intent(android.provider.Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
				data = android.net.Uri.parse("package:${context.packageName}")
				addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
			}
			context.startActivity(intent)
			true
		} catch (error: Throwable) {
			Log.w(TAG, "Unable to open exact-alarm settings", error)
			false
		}
	}

	fun callbackHandle(context: Context): Long {
		return context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
			.getLong(KEY_CALLBACK_HANDLE, 0L)
	}

	fun locale(context: Context): String {
		val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
			.getString(KEY_LOCALE, DEFAULT_LOCALE) ?: DEFAULT_LOCALE
		return normalizeLocale(raw)
	}

	fun isEnabled(context: Context): Boolean {
		return context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
			.getBoolean(KEY_ENABLED, false)
	}

	fun nextTriggerAtMillis(context: Context): Long {
		return context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
			.getLong(KEY_NEXT_TRIGGER_AT, 0L)
	}

	fun appendDiagnostic(context: Context, event: String) {
		AutoBackupDiagnosticsStore.append(context, event)
	}

	private fun normalizeLocale(locale: String): String {
		val trimmed = locale.trim().lowercase()
		if (trimmed.startsWith("en")) {
			return "en"
		}
		return "ar"
	}

	private fun armAlarm(context: Context, triggerAtMillis: Long) {
		val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
		val intent = pendingIntent(context)
		val elapsed = SystemClock.elapsedRealtime() +
			(triggerAtMillis - System.currentTimeMillis()).coerceAtLeast(5_000L)

		try {
			if (canScheduleExactAlarms(context)) {
				alarmManager.setExactAndAllowWhileIdle(
					AlarmManager.ELAPSED_REALTIME_WAKEUP,
					elapsed,
					intent,
				)
			} else {
				alarmManager.setAndAllowWhileIdle(
					AlarmManager.ELAPSED_REALTIME_WAKEUP,
					elapsed,
					intent,
				)
			}
		} catch (error: SecurityException) {
			Log.w(TAG, "Exact alarm denied; falling back to allow-while-idle", error)
			alarmManager.setAndAllowWhileIdle(
				AlarmManager.ELAPSED_REALTIME_WAKEUP,
				elapsed,
				intent,
			)
		}
	}

	private fun pendingIntent(context: Context): PendingIntent {
		val intent = Intent(context, AutoBackupAlarmReceiver::class.java).apply {
			action = AutoBackupAlarmReceiver.ACTION_FIRE
		}
		val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
		return PendingIntent.getBroadcast(context, REQUEST_CODE, intent, flags)
	}
}
