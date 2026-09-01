package com.akrmcodes.daftar.backup_notifier

import android.content.Context
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Posts auto-backup notifications and schedules Doze-piercing alarms.
 *
 * Channel IDs must match Dart [BackupNotificationIds] (`_v2`).
 */
class BackupNotifierPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
	private lateinit var channel: MethodChannel
	private lateinit var appContext: Context

	override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
		appContext = binding.applicationContext
		channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME)
		channel.setMethodCallHandler(this)
		AutoBackupChannels.ensureCreated(appContext)
	}

	override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
		channel.setMethodCallHandler(null)
	}

	override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
		when (call.method) {
			"ensureReady" -> {
				AutoBackupChannels.ensureCreated(appContext)
				AutoBackupChannels.cancelLegacyNotificationIds(appContext)
				result.success(null)
			}

			"areNotificationsEnabled" -> {
				result.success(AutoBackupChannels.areNotificationsEnabled(appContext))
			}

			"showNotification" -> {
				val id = call.argument<Int>("id")
				val channelId = call.argument<String>("channelId")
				val title = call.argument<String>("title")
				val body = call.argument<String>("body")
				if (id == null || channelId.isNullOrBlank() || title.isNullOrBlank() || body.isNullOrBlank()) {
					result.error("invalid_args", "Missing notification arguments", null)
					return
				}
				if (!AutoBackupChannels.areNotificationsEnabled(appContext)) {
					result.success(mapOf("posted" to false, "reason" to "notifications_disabled"))
					return
				}
				val ongoing = call.argument<Boolean>("ongoing") ?: false
				val urgent = call.argument<Boolean>("urgent") ?: false
				try {
					val notification = AutoBackupChannels.buildNotification(
						context = appContext,
						channelId = channelId,
						title = title,
						body = body,
						ongoing = ongoing,
						urgent = urgent,
					)
					NotificationManagerCompat.from(appContext).notify(id, notification)
					result.success(mapOf("posted" to true))
				} catch (error: Throwable) {
					result.error("show_failed", error.message, null)
				}
			}

			"cancelNotification" -> {
				val id = call.argument<Int>("id")
				if (id == null) {
					result.error("invalid_args", "Missing notification id", null)
					return
				}
				NotificationManagerCompat.from(appContext).cancel(id)
				result.success(null)
			}

			"scheduleAutoBackupAlarm" -> {
				val triggerAt = call.argument<Number>("triggerAtMillis")?.toLong()
				val interval = call.argument<Number>("intervalMillis")?.toLong()
				val callbackHandle = call.argument<Number>("callbackHandle")?.toLong()
				val locale = call.argument<String>("locale") ?: "ar"
				if (triggerAt == null || interval == null || callbackHandle == null) {
					result.error("invalid_args", "Missing alarm arguments", null)
					return
				}
				try {
					AutoBackupAlarmScheduler.schedule(
						context = appContext,
						triggerAtMillis = triggerAt,
						intervalMillis = interval,
						callbackHandle = callbackHandle,
						locale = locale,
					)
					AutoBackupDiagnosticsStore.append(appContext, "armed", "dart")
					result.success(
						mapOf(
							"exact" to AutoBackupAlarmScheduler.canScheduleExactAlarms(appContext),
							"triggerAtMillis" to triggerAt,
						),
					)
				} catch (error: Throwable) {
					result.error("schedule_failed", error.message, null)
				}
			}

			"cancelAutoBackupAlarm" -> {
				try {
					AutoBackupAlarmScheduler.cancel(appContext)
					result.success(null)
				} catch (error: Throwable) {
					result.error("cancel_failed", error.message, null)
				}
			}

			"canScheduleExactAlarms" -> {
				result.success(AutoBackupAlarmScheduler.canScheduleExactAlarms(appContext))
			}

			"openExactAlarmSettings" -> {
				result.success(AutoBackupAlarmScheduler.openExactAlarmSettings(appContext))
			}

			"getAlarmState" -> {
				result.success(
					mapOf(
						"enabled" to AutoBackupAlarmScheduler.isEnabled(appContext),
						"nextTriggerAtMillis" to AutoBackupAlarmScheduler.nextTriggerAtMillis(appContext),
						"canExact" to AutoBackupAlarmScheduler.canScheduleExactAlarms(appContext),
					),
				)
			}

			"readDiagnostics" -> {
				result.success(AutoBackupDiagnosticsStore.readAll(appContext))
			}

			"clearDiagnostics" -> {
				AutoBackupDiagnosticsStore.clear(appContext)
				result.success(null)
			}

			"appendDiagnostic" -> {
				val event = call.argument<String>("event") ?: return result.error(
					"invalid_args",
					"Missing event",
					null,
				)
				val source = call.argument<String>("source") ?: "dart"
				AutoBackupDiagnosticsStore.append(appContext, event, source)
				result.success(null)
			}

			else -> result.notImplemented()
		}
	}

	private companion object {
		const val CHANNEL_NAME = "daftar/backup_notifier"
	}
}
