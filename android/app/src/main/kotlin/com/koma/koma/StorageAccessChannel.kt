package com.koma.koma

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.Settings
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream

/**
 * Shared-storage access for the user data folder.
 *
 * Android 11+ blocks dart:io [File.copy] into `/storage/emulated/0/…`
 * unless the app is the All-files manager. Isar also needs a real
 * filesystem path there, so SAF URIs are not enough.
 */
class StorageAccessChannel(private val activity: Activity) {

    fun register(channel: MethodChannel) {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "hasAllFilesAccess" -> result.success(hasAllFilesAccess())
                "requestAllFilesAccess" -> {
                    requestAllFilesAccess()
                    result.success(null)
                }
                "copyFile" -> {
                    val from = call.argument<String>("from")
                    val to = call.argument<String>("to")
                    if (from.isNullOrEmpty() || to.isNullOrEmpty()) {
                        result.error("COPY", "missing from/to", null)
                        return@setMethodCallHandler
                    }
                    Thread {
                        try {
                            copyFile(from, to)
                            activity.runOnUiThread { result.success(null) }
                        } catch (e: Throwable) {
                            activity.runOnUiThread {
                                result.error("COPY", e.message, null)
                            }
                        }
                    }.start()
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun hasAllFilesAccess(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return true
        return Environment.isExternalStorageManager()
    }

    private fun requestAllFilesAccess() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return
        val intent = Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION).apply {
            data = Uri.parse("package:${activity.packageName}")
        }
        try {
            activity.startActivity(intent)
        } catch (_: Exception) {
            activity.startActivity(Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION))
        }
    }

    private fun copyFile(from: String, to: String) {
        val src = File(from)
        val dest = File(to)
        dest.parentFile?.mkdirs()
        FileInputStream(src).use { input ->
            FileOutputStream(dest).use { output ->
                input.copyTo(output, 64 * 1024)
            }
        }
    }
}
