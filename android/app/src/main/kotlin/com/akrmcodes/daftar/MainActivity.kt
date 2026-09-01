package com.akrmcodes.daftar

import android.content.ContentValues
import android.content.Intent
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.IOException
import kotlin.system.exitProcess

class MainActivity : FlutterFragmentActivity() {
	private companion object {
		const val PUBLIC_DOWNLOADS_CHANNEL = "daftar/public_downloads"
		const val COPY_METHOD = "copyBackupToDownloadsDaftar"
		const val APP_RESTARTER_CHANNEL = "daftar/app_restarter"
		const val RESTART_APP_METHOD = "restartApp"
		const val BACKUP_FOLDER = "Daftar"
		const val BACKUP_MIME_TYPE = "application/octet-stream"
	}

	override fun onCreate(savedInstanceState: android.os.Bundle?) {
		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
			// Remove Android 12 splash exit fade — Flutter curtain continues the same frame.
			splashScreen.setOnExitAnimationListener { splashScreenView ->
				splashScreenView.remove()
			}
		}
		super.onCreate(savedInstanceState)
		com.akrmcodes.daftar.backup_notifier.AutoBackupChannels.ensureCreated(this)
	}

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(
			flutterEngine.dartExecutor.binaryMessenger,
			PUBLIC_DOWNLOADS_CHANNEL,
		).setMethodCallHandler { call, result ->
			when (call.method) {
				COPY_METHOD -> {
					val sourceFilePath = call.argument<String>("sourceFilePath")
					val fileName = call.argument<String>("fileName")

					if (sourceFilePath.isNullOrBlank() || fileName.isNullOrBlank()) {
						result.success(false)
						return@setMethodCallHandler
					}

					result.success(
						copyBackupToPublicDownloads(
							sourceFilePath = sourceFilePath,
							fileName = fileName,
						),
					)
				}

				else -> result.notImplemented()
			}
		}

		MethodChannel(
			flutterEngine.dartExecutor.binaryMessenger,
			APP_RESTARTER_CHANNEL,
		).setMethodCallHandler { call, result ->
			when (call.method) {
				RESTART_APP_METHOD -> {
					val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
					if (launchIntent == null) {
						result.error(
							"NO_LAUNCH_INTENT",
							"Unable to resolve launch intent for $packageName",
							null,
						)
						return@setMethodCallHandler
					}

					launchIntent.addFlags(
						Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK,
					)
					startActivity(launchIntent)
					result.success(null)
					exitProcess(0)
				}

				else -> result.notImplemented()
			}
		}
	}

	private fun copyBackupToPublicDownloads(
		sourceFilePath: String,
		fileName: String,
	): Boolean {
		val sourceFile = File(sourceFilePath)
		if (!sourceFile.exists()) {
			return false
		}

		return try {
			if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
				copyViaMediaStore(sourceFile, fileName)
			} else {
				copyViaLegacyDownloadsFolder(sourceFile, fileName)
			}
		} catch (_: Throwable) {
			false
		}
	}

	private fun copyViaMediaStore(sourceFile: File, fileName: String): Boolean {
		val resolver = applicationContext.contentResolver
		val collection = MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
		val relativePath = Environment.DIRECTORY_DOWNLOADS + "/$BACKUP_FOLDER/"

		val values = ContentValues().apply {
			put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
			put(MediaStore.MediaColumns.MIME_TYPE, BACKUP_MIME_TYPE)
			put(MediaStore.MediaColumns.RELATIVE_PATH, relativePath)
			put(MediaStore.MediaColumns.IS_PENDING, 1)
		}

		val itemUri = resolver.insert(collection, values) ?: return false

		return try {
			resolver.openOutputStream(itemUri, "w")?.use { outputStream ->
				FileInputStream(sourceFile).use { inputStream ->
					inputStream.copyTo(outputStream)
				}
			} ?: throw IOException("Unable to open MediaStore output stream")

			resolver.update(
				itemUri,
				ContentValues().apply {
					put(MediaStore.MediaColumns.IS_PENDING, 0)
				},
				null,
				null,
			)
			true
		} catch (_: Throwable) {
			resolver.delete(itemUri, null, null)
			false
		}
	}

	@Suppress("DEPRECATION")
	private fun copyViaLegacyDownloadsFolder(sourceFile: File, fileName: String): Boolean {
		val downloadsDirectory = Environment.getExternalStoragePublicDirectory(
			Environment.DIRECTORY_DOWNLOADS,
		)
		val daftarDirectory = File(downloadsDirectory, BACKUP_FOLDER)
		if (!daftarDirectory.exists() && !daftarDirectory.mkdirs()) {
			return false
		}

		val destinationFile = File(daftarDirectory, fileName)
		return try {
			FileInputStream(sourceFile).use { inputStream ->
				destinationFile.outputStream().use { outputStream ->
					inputStream.copyTo(outputStream)
				}
			}
			true
		} catch (_: Throwable) {
			false
		}
	}
}
