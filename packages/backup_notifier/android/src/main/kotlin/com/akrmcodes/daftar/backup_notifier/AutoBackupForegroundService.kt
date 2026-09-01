package com.akrmcodes.daftar.backup_notifier

import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.util.Log
import androidx.core.app.ServiceCompat
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.FlutterCallbackInformation

/**
 * dataSync foreground service that hosts a headless FlutterEngine and runs
 * the auto-backup Dart entry point while the phone is idle / screen-off.
 *
 * Uses [AutoBackupChannels.STATUS_NOTIFICATION_ID] so Dart outcome updates
 * replace this notification in place (no English/Arabic dual tray).
 */
class AutoBackupForegroundService : Service() {
	private var engine: FlutterEngine? = null
	private var wakeLock: PowerManager.WakeLock? = null
	private val mainHandler = Handler(Looper.getMainLooper())
	private var stopped = false

	override fun onBind(intent: Intent?): IBinder? = null

	override fun onCreate() {
		super.onCreate()
		AutoBackupChannels.ensureCreated(this)
		acquireWakeLock()
	}

	override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
		val locale = AutoBackupAlarmScheduler.locale(this)
		val (title, body) = AutoBackupChannels.inProgressCopy(locale)
		val notification = AutoBackupChannels.buildInProgressNotification(this, title, body)

		try {
			val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
				ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
			} else {
				0
			}
			ServiceCompat.startForeground(
				this,
				AutoBackupChannels.STATUS_NOTIFICATION_ID,
				notification,
				type,
			)
			AutoBackupDiagnosticsStore.append(this, "fgs_running", "fgs")
		} catch (error: Throwable) {
			Log.e(TAG, "startForeground failed", error)
			AutoBackupDiagnosticsStore.append(this, "fgs_failed:$error", "fgs")
			stopSelfSafely()
			return START_NOT_STICKY
		}

		mainHandler.post { startDartEngine() }
		return START_NOT_STICKY
	}

	override fun onTimeout(startId: Int, fgsType: Int) {
		Log.w(TAG, "dataSync FGS timed out; stopping")
		AutoBackupDiagnosticsStore.append(this, "fgs_timeout", "fgs")
		stopSelfSafely()
	}

	override fun onDestroy() {
		stopped = true
		destroyEngine()
		releaseWakeLock()
		super.onDestroy()
	}

	private fun startDartEngine() {
		if (stopped) {
			return
		}
		val callbackHandle = AutoBackupAlarmScheduler.callbackHandle(this)
		if (callbackHandle == 0L) {
			Log.e(TAG, "No Dart callback handle")
			AutoBackupDiagnosticsStore.append(this, "failed:no_callback", "fgs")
			stopSelfSafely()
			return
		}

		try {
			val loader = FlutterInjector.instance().flutterLoader()
			if (!loader.initialized()) {
				loader.startInitialization(applicationContext)
			}
			loader.ensureInitializationComplete(applicationContext, null)

			val callbackInfo =
				FlutterCallbackInformation.lookupCallbackInformation(callbackHandle)
			if (callbackInfo == null) {
				Log.e(TAG, "Failed to resolve Dart callback $callbackHandle")
				AutoBackupDiagnosticsStore.append(this, "failed:bad_callback", "fgs")
				stopSelfSafely()
				return
			}

			val localEngine = FlutterEngine(applicationContext)
			engine = localEngine

			val channel = MethodChannel(
				localEngine.dartExecutor.binaryMessenger,
				SERVICE_CHANNEL,
			)
			channel.setMethodCallHandler { call, result ->
				when (call.method) {
					"taskCompleted" -> {
						result.success(null)
						AutoBackupDiagnosticsStore.append(this, "success", "fgs")
						stopSelfSafely()
					}
					else -> result.notImplemented()
				}
			}

			localEngine.dartExecutor.executeDartCallback(
				DartExecutor.DartCallback(
					assets,
					loader.findAppBundlePath(),
					callbackInfo,
				),
			)
		} catch (error: Throwable) {
			Log.e(TAG, "Failed to start Dart engine", error)
			AutoBackupDiagnosticsStore.append(this, "failed:$error", "fgs")
			stopSelfSafely()
		}
	}

	private fun stopSelfSafely() {
		mainHandler.post {
			try {
				// DETACH keeps the final Dart outcome notification in the tray.
				ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_DETACH)
			} catch (_: Throwable) {
				// Best-effort.
			}
			destroyEngine()
			releaseWakeLock()
			stopSelf()
		}
	}

	private fun destroyEngine() {
		try {
			engine?.destroy()
		} catch (_: Throwable) {
			// Best-effort.
		}
		engine = null
	}

	private fun acquireWakeLock() {
		val powerManager = getSystemService(POWER_SERVICE) as PowerManager
		wakeLock = powerManager.newWakeLock(
			PowerManager.PARTIAL_WAKE_LOCK,
			"daftar:auto_backup_fgs",
		).also {
			it.acquire(10 * 60 * 1000L)
		}
	}

	private fun releaseWakeLock() {
		try {
			if (wakeLock?.isHeld == true) {
				wakeLock?.release()
			}
		} catch (_: Throwable) {
			// Best-effort.
		}
		wakeLock = null
	}

	companion object {
		private const val TAG = "DaftarAutoBackup"
		private const val SERVICE_CHANNEL = "daftar/auto_backup_service"
	}
}
