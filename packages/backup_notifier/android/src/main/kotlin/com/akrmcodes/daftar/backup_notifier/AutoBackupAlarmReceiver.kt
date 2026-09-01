package com.akrmcodes.daftar.backup_notifier

import android.app.ForegroundServiceStartNotAllowedException
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.PowerManager
import android.util.Log
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import java.util.concurrent.TimeUnit

/**
 * Fires when the Doze-piercing auto-backup alarm triggers.
 *
 * Tries to start [AutoBackupForegroundService]; on
 * [ForegroundServiceStartNotAllowedException] falls back to a zero-delay
 * WorkManager one-off. Always re-arms the next alarm.
 */
class AutoBackupAlarmReceiver : BroadcastReceiver() {
	override fun onReceive(context: Context, intent: Intent?) {
		if (intent?.action != ACTION_FIRE) {
			return
		}
		val pendingResult = goAsync()
		val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
		val wakeLock = powerManager.newWakeLock(
			PowerManager.PARTIAL_WAKE_LOCK,
			"daftar:auto_backup_alarm",
		)
		wakeLock.acquire(10 * 60 * 1000L)

		try {
			AutoBackupDiagnosticsStore.append(context, "alarm_fired", "alarm")
			AutoBackupChannels.ensureCreated(context)

			val started = startForegroundServiceSafely(context)
			if (!started) {
				enqueueWorkManagerFallback(context)
			}

			// Re-arm next interval so a missed FGS/WM still keeps the chain alive.
			AutoBackupAlarmScheduler.scheduleNextFromPrefs(context)
			AutoBackupDiagnosticsStore.append(context, "armed", "alarm")
		} catch (error: Throwable) {
			Log.e(TAG, "Alarm receiver failed", error)
			AutoBackupDiagnosticsStore.append(context, "failed:$error", "alarm")
			try {
				enqueueWorkManagerFallback(context)
				AutoBackupAlarmScheduler.scheduleNextFromPrefs(context)
			} catch (fallbackError: Throwable) {
				Log.e(TAG, "Alarm fallback also failed", fallbackError)
			}
		} finally {
			try {
				if (wakeLock.isHeld) {
					wakeLock.release()
				}
			} catch (_: Throwable) {
				// Best-effort.
			}
			pendingResult.finish()
		}
	}

	private fun startForegroundServiceSafely(context: Context): Boolean {
		val serviceIntent = Intent(context, AutoBackupForegroundService::class.java)
		return try {
			if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
				context.startForegroundService(serviceIntent)
			} else {
				context.startService(serviceIntent)
			}
			AutoBackupDiagnosticsStore.append(context, "fgs_started", "alarm")
			true
		} catch (error: Throwable) {
			val blocked = Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
				error is ForegroundServiceStartNotAllowedException
			if (blocked) {
				AutoBackupDiagnosticsStore.append(context, "fgs_blocked", "alarm")
				Log.w(TAG, "FGS start blocked from background; using WorkManager", error)
			} else {
				AutoBackupDiagnosticsStore.append(context, "fgs_failed:$error", "alarm")
				Log.e(TAG, "FGS start failed", error)
			}
			false
		}
	}

	private fun enqueueWorkManagerFallback(context: Context) {
		AutoBackupDiagnosticsStore.append(context, "wm_fallback", "alarm")
		val request = OneTimeWorkRequestBuilder<AutoBackupFallbackWorker>()
			.setInitialDelay(0, TimeUnit.MILLISECONDS)
			.build()
		WorkManager.getInstance(context).enqueueUniqueWork(
			FALLBACK_UNIQUE_NAME,
			ExistingWorkPolicy.REPLACE,
			request,
		)
	}

	companion object {
		const val ACTION_FIRE = "com.akrmcodes.daftar.backup_notifier.ACTION_AUTO_BACKUP_FIRE"
		const val FALLBACK_UNIQUE_NAME = "com.akrmcodes.daftar.autobackup.alarm_fallback"
		private const val TAG = "DaftarAutoBackup"
	}
}
