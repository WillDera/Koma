package eu.kanade.tachiyomi.extension

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import eu.kanade.tachiyomi.extension.DalvikRuntimeManager.getOrStartServer
import java.io.IOException
import java.net.InetSocketAddress
import java.net.Socket

/**
 * Application-scoped owner of the extension runtime (DalvikServer).
 *
 * The runtime is no longer owned by the Activity: it is lazily started on first
 * use (MainActivity, a WorkManager background task, a notification action, …)
 * so the extension runtime can be shared by every background component the app
 * grows into (library polling, extension updates, downloads, sync).
 *
 * Every caller goes through [getOrStartServer]:
 * - first caller boots the server,
 * - everyone else reuses the running instance,
 * - a stale port is detected via a TCP probe and the server is restarted.
 *
 * Only the main process may own the runtime. The live port is mirrored into
 * Flutter's shared_preferences store so a background isolate (which has no
 * MethodChannel) can discover it via `SharedPreferences.getInt('dalvik_port')`.
 */
object DalvikRuntimeManager {
    private const val TAG = "DalvikRuntimeManager"
    private const val PREFS_NAME = "FlutterSharedPreferences"
    // Dart SharedPreferences.getInt('dalvik_port') stores/reads the native key
    // with the "flutter." prefix. Flutter setInt writes Longs — use putLong.
    private const val KEY_PORT = "dalvik_port"
    private const val KEY_PORT_PREF = "flutter.$KEY_PORT"

    @Volatile
    private var appContext: Context? = null

    private val lock = Any()

    /** Idempotent — safe to call from Application.onCreate, MainActivity, workers. */
    fun initialize(context: Context) {
        if (appContext == null) {
            synchronized(lock) {
                if (appContext == null) appContext = context.applicationContext
            }
        }
    }

    /** True when the current process is the main app process (owns the runtime). */
    fun isMainProcess(): Boolean {
        val ctx = appContext ?: return false
        return ctx.applicationInfo.processName == ctx.packageName
    }

    /**
     * Lazily start (or reuse / restart) the DalvikServer and return a live port.
     * Never called from a background process — background components run in the
     * same process as the app, so this is only guarded to protect future
     * multi-process services from double-binding the socket.
     */
    fun getOrStartServer(): Int {
        val ctx = appContext
            ?: throw IllegalStateException("DalvikRuntimeManager not initialized")
        check(isMainProcess()) { "DalvikRuntimeManager must run in the main process" }
        return synchronized(lock) {
            val server = DalvikServer.initialize(ctx)
            var port = server.port
            if (port <= 0 || !isAlive(port)) {
                if (port > 0) {
                    Log.w(TAG, "stale port $port — restarting")
                    server.stop()
                }
                port = server.start()
            }
            persistPort(port)
            port
        }
    }

    /** Port currently owned by the runtime, without starting anything. */
    fun currentPort(): Int {
        return try {
            DalvikServer.getInstance().port
        } catch (_: Throwable) {
            -1
        }
    }

    /** Cheap TCP probe: true if something is accepting connections on [port]. */
    fun isAlive(port: Int): Boolean {
        if (port <= 0) return false
        return try {
            Socket().use {
                it.connect(InetSocketAddress("127.0.0.1", port), 300)
            }
            true
        } catch (_: IOException) {
            false
        }
    }

    /**
     * Mirror the port into Flutter's shared_preferences store (legacy channel
     * persists to file "FlutterSharedPreferences" with a "flutter." key prefix).
     * A WorkManager background isolate — whose FlutterEngine has no
     * getDalvikPort MethodChannel handler — reads this via
     * `SharedPreferences.getInstance().getInt('dalvik_port')`.
     */
    private fun persistPort(port: Int) {
        val ctx = appContext ?: return
        try {
            val prefs: SharedPreferences =
                ctx.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit().putLong(KEY_PORT_PREF, port.toLong()).apply()
        } catch (e: Throwable) {
            Log.w(TAG, "persistPort failed", e)
        }
    }
}
