package com.koma.koma

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInstaller
import android.util.Log
import java.io.File
import java.io.FileInputStream

/**
 * Mihon [PackageInstallerInstaller] parity — session-based APK install with
 * status callback via [ExtensionInstallReceiver].
 */
object PackageInstallerHelper {
    fun install(context: Context, apkPath: String) {
        val file = File(apkPath)
        if (!file.exists()) throw IllegalArgumentException("apk not found: $apkPath")

        val installer = context.packageManager.packageInstaller
        val params = PackageInstaller.SessionParams(
            PackageInstaller.SessionParams.MODE_FULL_INSTALL,
        )
        val sessionId = installer.createSession(params)
        val session = installer.openSession(sessionId)
        FileInputStream(file).use { input ->
            session.openWrite("base.apk", 0, file.length()).use { out ->
                input.copyTo(out)
                session.fsync(out)
            }
        }

        val intent = Intent(context, ExtensionInstallReceiver::class.java).apply {
            action = ExtensionInstallReceiver.ACTION_INSTALL_STATUS
        }
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        val pending = PendingIntent.getBroadcast(context, sessionId, intent, flags)
        session.commit(pending.intentSender)
        session.close()
        Log.i("PkgInstaller", "Committed session $sessionId for $apkPath")
    }
}
