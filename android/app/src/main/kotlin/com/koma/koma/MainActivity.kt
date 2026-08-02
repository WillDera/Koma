package com.koma.koma

import android.graphics.Typeface
import android.util.Log
import eu.kanade.tachiyomi.extension.DalvikRuntimeManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        DalvikRuntimeManager.initialize(applicationContext)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "eu.kanade.tachiyomi/keiyoushi",
        ).setMethodCallHandler { call, result ->
            if (call.method == "getDalvikPort") {
                // getOrStartServer probes the port with a TCP connect — must
                // not run on the main thread (StrictMode NetworkOnMainThread).
                Thread {
                    try {
                        val port = DalvikRuntimeManager.getOrStartServer()
                        runOnUiThread {
                            if (port > 0) result.success(port)
                            else result.error("NOSERVER", "Dalvik server not running", null)
                        }
                    } catch (e: Throwable) {
                        runOnUiThread {
                            result.error("NOSERVER", e.message, null)
                        }
                    }
                }.start()
            } else {
                result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.koma.koma/system",
        ).setMethodCallHandler { call, result ->
            if (call.method == "getSystemTypeface") {
                result.success(resolveSystemTypeface())
            } else {
                result.notImplemented()
            }
        }
    }

    private fun resolveSystemTypeface(): String {
        return try {
            val typeface = Typeface.create("sans-serif", Typeface.NORMAL)
            val family = typeface.toString()
            if (family.contains("sans-serif", ignoreCase = true)) {
                readSystemFontConfig() ?: "sans-serif"
            } else {
                family.substringAfterLast('.').ifEmpty { family }
            }
        } catch (e: Throwable) {
            Log.w("SystemFont", "Typeface query failed", e)
            readSystemFontConfig() ?: "sans-serif"
        }
    }

    private fun readSystemFontConfig(): String? {
        return try {
            val config = File("/system/etc/fonts.xml").takeIf { it.exists() }?.readText()
            if (config.isNullOrBlank()) return null
            val regex = Regex("<family name=\"sans-serif\">([^<]+)</family>")
            val match = regex.find(config)
            match?.groupValues?.getOrNull(1)?.trim()?.ifEmpty { null }
        } catch (e: Throwable) {
            Log.w("SystemFont", "font config parse failed", e)
            null
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        // The runtime is process-scoped (DalvikRuntimeManager): it must survive
        // the Activity's engine so background WorkManager tasks can reuse it.
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
