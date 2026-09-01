package com.akrmcodes.daftar.backup_notifier

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/**
 * SharedPreferences ring buffer of auto-backup diagnostic events.
 *
 * Readable from Dart via MethodChannel and writable from every native
 * trigger path (alarm, boot, FGS, WorkManager fallback).
 */
object AutoBackupDiagnosticsStore {
	private const val PREFS = "daftar_auto_backup_diagnostics"
	private const val KEY_EVENTS = "events_json"
	private const val MAX_EVENTS = 30

	fun append(context: Context, event: String, source: String = "native") {
		val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
		val existing = prefs.getString(KEY_EVENTS, "[]") ?: "[]"
		val array = try {
			JSONArray(existing)
		} catch (_: Throwable) {
			JSONArray()
		}
		val entry = JSONObject()
			.put("event", event)
			.put("source", source)
			.put("at", System.currentTimeMillis())
		array.put(entry)

		val trimmed = JSONArray()
		val start = (array.length() - MAX_EVENTS).coerceAtLeast(0)
		for (i in start until array.length()) {
			trimmed.put(array.get(i))
		}
		prefs.edit().putString(KEY_EVENTS, trimmed.toString()).apply()
	}

	fun readAll(context: Context): String {
		return context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
			.getString(KEY_EVENTS, "[]") ?: "[]"
	}

	fun clear(context: Context) {
		context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
			.edit()
			.remove(KEY_EVENTS)
			.apply()
	}
}
