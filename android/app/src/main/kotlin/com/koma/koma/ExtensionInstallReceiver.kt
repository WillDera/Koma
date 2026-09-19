package com.koma.koma

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInstaller
import android.util.Log
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel

/**
 * PackageInstaller session status. Manifest-exported is false — only an
 * explicit PendingIntent from [PackageInstallerHelper] can deliver here.
 */
class ExtensionInstallReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION_INSTALL_STATUS) return
        val status = intent.getIntExtra(
            PackageInstaller.EXTRA_STATUS,
            PackageInstaller.STATUS_FAILURE,
        )
        val msg = intent.getStringExtra(PackageInstaller.EXTRA_STATUS_MESSAGE)
        Log.i(TAG, "PackageInstaller status=$status msg=$msg")
        notifyDart("onPackageInstallerStatus", mapOf("status" to status, "message" to msg))
    }

    companion object {
        const val TAG = "ExtInstallRx"
        const val ACTION_INSTALL_STATUS = "com.koma.koma.INSTALL_STATUS"
        const val CHANNEL = "com.koma.koma/extensions"
        const val ENGINE_ID = "koma_main"

        fun notifyDart(method: String, args: Map<String, Any?>) {
            val engine = FlutterEngineCache.getInstance().get(ENGINE_ID) ?: return
            MethodChannel(
                engine.dartExecutor.binaryMessenger,
                CHANNEL,
            ).invokeMethod(method, args)
        }
    }
}

/**
 * System PACKAGE_ADDED / REPLACED / REMOVED. Must stay exported so the OS can
 * deliver implicit package broadcasts.
 */
class ExtensionPackageChangeReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_PACKAGE_ADDED,
            Intent.ACTION_PACKAGE_REPLACED,
            Intent.ACTION_PACKAGE_REMOVED -> {
                val pkg = intent.data?.schemeSpecificPart ?: return
                Log.i(ExtensionInstallReceiver.TAG, "Package change: ${intent.action} $pkg")
                ExtensionInstallReceiver.notifyDart(
                    "onExtensionPackageChanged",
                    mapOf("action" to intent.action, "package" to pkg),
                )
            }
        }
    }
}
