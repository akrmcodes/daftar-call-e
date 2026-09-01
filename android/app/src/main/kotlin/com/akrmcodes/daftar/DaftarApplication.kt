package com.akrmcodes.daftar

import android.app.Application
import com.akrmcodes.daftar.backup_notifier.AutoBackupChannels

class DaftarApplication : Application() {
	override fun onCreate() {
		super.onCreate()
		AutoBackupChannels.ensureCreated(this)
	}
}
