package com.koma.koma

import android.app.Application
import android.content.SharedPreferences
import android.webkit.CookieManager
import eu.kanade.tachiyomi.extension.DalvikRuntimeManager

/**
 * Application-scoped entry point. Registered in AndroidManifest so the
 * extension runtime (DalvikServer) can be started without the Activity —
 * required for WorkManager background library polling, which runs in a
 * separate engine but the same process.
 *
 * The runtime is only started here when the user has enabled auto-update for
 * the library, so a process wake triggered by WorkManager finds the server up.
 * Regular cold launches (no auto-update) stay fast: nothing boots until the
 * Activity or a background task actually needs the runtime.
 */
class KomaApplication : Application() {

    override fun onCreate() {
        super.onCreate()
        // Shared with OkHttp [AndroidCookieJar] + extension runWebView.
        runCatching { CookieManager.getInstance().setAcceptCookie(true) }
        DalvikRuntimeManager.initialize(this)
        if (isAutoUpdateEnabled()) {
            try {
                DalvikRuntimeManager.getOrStartServer()
            } catch (e: Throwable) {
                // Background wake with the server unavailable: the poll will
                // fail gracefully and the next app launch recovers.
            }
        }
    }

    private fun isAutoUpdateEnabled(): Boolean {
        return try {
            val prefs: SharedPreferences = getSharedPreferences(
                "FlutterSharedPreferences",
                MODE_PRIVATE,
            )
            prefs.getBoolean("flutter.library_auto_update_enabled", false)
        } catch (e: Throwable) {
            false
        }
    }
}
