package com.akrmcodes.daftar.backup_notifier

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

/**
 * Single source of truth for auto-backup notification channels and builders.
 *
 * Channel IDs must match Dart [BackupNotificationIds] (`_v2` suffix).
 */
object AutoBackupChannels {
	const val ALERTS_CHANNEL_ID = "daftar_auto_backup_v2"
	const val ALERTS_CHANNEL_NAME = "Auto Backup"
	const val URGENT_CHANNEL_ID = "daftar_auto_backup_urgent_v2"
	const val URGENT_CHANNEL_NAME = "Auto Backup Alerts"
	const val CHANNEL_DESCRIPTION = "Google Drive automatic backup status"

	private const val LEGACY_ALERTS_CHANNEL_ID = "daftar_auto_backup_v1"
	private const val LEGACY_URGENT_CHANNEL_ID = "daftar_auto_backup_urgent_v1"

	/** Single tray id for the whole auto-backup run (in-progress → outcome). */
	const val STATUS_NOTIFICATION_ID = 0x00ABAC01

	/** @deprecated Kept only to cancel stuck notifications from older builds. */
	const val LEGACY_OUTCOME_NOTIFICATION_ID = 0x00ABAC02

	/** @deprecated Separate FGS id caused English+Arabic doubles; cancel on ready. */
	const val LEGACY_FGS_NOTIFICATION_ID = 0x00ABAC03

	private const val NOTIFICATION_ICON = "ic_backup_notify"

	fun ensureCreated(context: Context) {
		if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
			return
		}
		val manager = context.getSystemService(NotificationManager::class.java) ?: return

		// Drop frozen v1 channels so importance/visibility changes take effect.
		manager.deleteNotificationChannel(LEGACY_ALERTS_CHANNEL_ID)
		manager.deleteNotificationChannel(LEGACY_URGENT_CHANNEL_ID)

		// Clear stuck dual-tray notifications from pre-unify builds.
		cancelLegacyNotificationIds(context)

		val soundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
		val audioAttrs = AudioAttributes.Builder()
			.setUsage(AudioAttributes.USAGE_NOTIFICATION)
			.setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
			.build()
		val vibration = longArrayOf(0, 500, 200, 500, 200, 500)

		val standard = NotificationChannel(
			ALERTS_CHANNEL_ID,
			ALERTS_CHANNEL_NAME,
			NotificationManager.IMPORTANCE_HIGH,
		).apply {
			description = CHANNEL_DESCRIPTION
			lockscreenVisibility = Notification.VISIBILITY_PUBLIC
			setShowBadge(true)
			enableVibration(true)
			vibrationPattern = vibration
			setSound(soundUri, audioAttrs)
		}

		val urgent = NotificationChannel(
			URGENT_CHANNEL_ID,
			URGENT_CHANNEL_NAME,
			NotificationManager.IMPORTANCE_HIGH,
		).apply {
			description = CHANNEL_DESCRIPTION
			lockscreenVisibility = Notification.VISIBILITY_PUBLIC
			setShowBadge(true)
			enableVibration(true)
			vibrationPattern = vibration
			setSound(soundUri, audioAttrs)
		}

		manager.createNotificationChannel(standard)
		manager.createNotificationChannel(urgent)
	}

	fun areNotificationsEnabled(context: Context): Boolean {
		return NotificationManagerCompat.from(context).areNotificationsEnabled()
	}

	fun buildNotification(
		context: Context,
		channelId: String,
		title: String,
		body: String,
		ongoing: Boolean,
		urgent: Boolean,
	): Notification {
		ensureCreated(context)
		val smallIcon = resolveSmallIcon(context)
		val contentIntent = launchPendingIntent(context)
		val category = if (urgent) {
			NotificationCompat.CATEGORY_ERROR
		} else {
			NotificationCompat.CATEGORY_STATUS
		}

		return NotificationCompat.Builder(context, channelId)
			.setSmallIcon(smallIcon)
			.setContentTitle(title)
			.setContentText(body)
			.setStyle(NotificationCompat.BigTextStyle().bigText(body))
			.setPriority(
				if (urgent) {
					NotificationCompat.PRIORITY_MAX
				} else {
					NotificationCompat.PRIORITY_HIGH
				},
			)
			.setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
			.setCategory(category)
			.setContentIntent(contentIntent)
			.setOngoing(ongoing)
			.setAutoCancel(!ongoing)
			.setOnlyAlertOnce(ongoing)
			.setShowWhen(true)
			.setWhen(System.currentTimeMillis())
			.setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
			.build()
	}

	fun buildInProgressNotification(context: Context, title: String, body: String): Notification {
		return buildNotification(
			context = context,
			channelId = ALERTS_CHANNEL_ID,
			title = title,
			body = body,
			ongoing = true,
			urgent = false,
		)
	}

	/** Locale-aware in-progress copy matching ARB backupAutoNotifInProgress*. */
	fun inProgressCopy(locale: String): Pair<String, String> {
		val isArabic = locale.lowercase().startsWith("ar")
		return if (isArabic) {
			"نسخ احتياطي تلقائي" to
				"جاري رفع نسخة دفتر الاحتياطية إلى Google Drive…"
		} else {
			"Automatic backup" to
				"Uploading your encrypted Daftar backup to Google Drive…"
		}
	}

	fun cancelLegacyNotificationIds(context: Context) {
		val manager = NotificationManagerCompat.from(context)
		manager.cancel(LEGACY_OUTCOME_NOTIFICATION_ID)
		manager.cancel(LEGACY_FGS_NOTIFICATION_ID)
	}

	private fun resolveSmallIcon(context: Context): Int {
		val iconResId = context.resources.getIdentifier(
			NOTIFICATION_ICON,
			"drawable",
			context.packageName,
		)
		return if (iconResId != 0) iconResId else android.R.drawable.ic_menu_upload
	}

	private fun launchPendingIntent(context: Context): PendingIntent {
		val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
			?: Intent().apply {
				setPackage(context.packageName)
				addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
			}
		launchIntent.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
		val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
		return PendingIntent.getActivity(context, 0, launchIntent, flags)
	}
}
