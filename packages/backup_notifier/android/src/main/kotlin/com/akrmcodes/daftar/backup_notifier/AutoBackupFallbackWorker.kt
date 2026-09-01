package com.akrmcodes.daftar.backup_notifier

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.embedding.engine.loader.FlutterLoader
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.FlutterCallbackInformation
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.withTimeoutOrNull

/**
 * Zero-constraint WorkManager fallback when the alarm cannot start an FGS.
 *
 * Hosts a headless FlutterEngine and executes the persisted Dart callback.
 */
class AutoBackupFallbackWorker(
	appContext: Context,
	params: WorkerParameters,
) : CoroutineWorker(appContext, params) {
	override suspend fun doWork(): Result {
		AutoBackupDiagnosticsStore.append(applicationContext, "wm_fallback_run", "worker")
		val completed = runDartCallback(applicationContext)
		return if (completed) Result.success() else Result.retry()
	}

	companion object {
		private const val TAG = "DaftarAutoBackup"
		private const val SERVICE_CHANNEL = "daftar/auto_backup_service"
		private const val TIMEOUT_MS = 9 * 60 * 1000L

		suspend fun runDartCallback(context: Context): Boolean {
			val callbackHandle = AutoBackupAlarmScheduler.callbackHandle(context)
			if (callbackHandle == 0L) {
				Log.e(TAG, "No Dart callback handle persisted")
				AutoBackupDiagnosticsStore.append(context, "failed:no_callback", "worker")
				return false
			}

			val done = CompletableDeferred<Boolean>()
			val mainHandler = Handler(Looper.getMainLooper())

			mainHandler.post {
				var engine: FlutterEngine? = null
				try {
					val loader: FlutterLoader = FlutterInjector.instance().flutterLoader()
					if (!loader.initialized()) {
						loader.startInitialization(context)
					}
					loader.ensureInitializationComplete(context, null)

					val callbackInfo =
						FlutterCallbackInformation.lookupCallbackInformation(callbackHandle)
					if (callbackInfo == null) {
						Log.e(TAG, "Failed to resolve Dart callback $callbackHandle")
						AutoBackupDiagnosticsStore.append(context, "failed:bad_callback", "worker")
						done.complete(false)
						return@post
					}

					engine = FlutterEngine(context.applicationContext)
					val channel = MethodChannel(
						engine!!.dartExecutor.binaryMessenger,
						SERVICE_CHANNEL,
					)
					channel.setMethodCallHandler { call, result ->
						when (call.method) {
							"taskCompleted" -> {
								result.success(null)
								done.complete(true)
								mainHandler.post {
									engine?.destroy()
									engine = null
								}
							}
							else -> result.notImplemented()
						}
					}

					engine!!.dartExecutor.executeDartCallback(
						DartExecutor.DartCallback(
							context.assets,
							loader.findAppBundlePath(),
							callbackInfo,
						),
					)
				} catch (error: Throwable) {
					Log.e(TAG, "Dart callback execution failed", error)
					AutoBackupDiagnosticsStore.append(context, "failed:$error", "worker")
					engine?.destroy()
					done.complete(false)
				}
			}

			val result = withTimeoutOrNull(TIMEOUT_MS) { done.await() } ?: false
			if (!result) {
				AutoBackupDiagnosticsStore.append(context, "failed:timeout", "worker")
			}
			return result
		}
	}
}
