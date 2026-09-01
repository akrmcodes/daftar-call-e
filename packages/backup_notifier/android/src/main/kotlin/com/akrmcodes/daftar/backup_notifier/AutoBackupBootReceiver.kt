package com.akrmcodes.daftar.backup_notifier

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Re-arms the Doze-piercing auto-backup alarm after reboot / package replace /
 * time changes. Does NOT start the foreground service (Android 15+ forbids
 * launching dataSync FGS from BOOT_COMPLETED).
 */
class AutoBackupBootReceiver : BroadcastReceiver() {
	override fun onReceive(context: Context, intent: Intent?) {
		val action = intent?.action ?: return
		when (action) {
			Intent.ACTION_BOOT_COMPLETED,
			Intent.ACTION_MY_PACKAGE_REPLACED,
			Intent.ACTION_TIME_CHANGED,
			Intent.ACTION_TIMEZONE_CHANGED,
			-> {
				try {
					AutoBackupChannels.ensureCreated(context)
					if (AutoBackupAlarmScheduler.isEnabled(context)) {
						AutoBackupAlarmScheduler.rearmFromPrefs(context)
						AutoBackupDiagnosticsStore.append(context, "armed", "boot:$action")
						Log.i(TAG, "Re-armed auto-backup alarm after $action")
					}
				} catch (error: Throwable) {
					Log.e(TAG, "Boot re-arm failed", error)
					AutoBackupDiagnosticsStore.append(context, "failed:$error", "boot")
				}
			}
		}
	}

	private companion object {
		const val TAG = "DaftarAutoBackup"
	}
}
