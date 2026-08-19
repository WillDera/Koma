package com.koma.koma

import android.app.SearchManager
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.BatteryManager
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.MediaStore
import android.util.Log
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import androidx.core.content.FileProvider
import androidx.core.content.pm.PackageInfoCompat
import com.koma.koma.piper.PiperMethodChannel
import eu.kanade.tachiyomi.extension.DalvikRuntimeManager
import eu.kanade.tachiyomi.extension.DalvikServer
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.security.MessageDigest

class MainActivity : FlutterActivity() {

    private var piperChannel: PiperMethodChannel? = null
    private var searchChannel: MethodChannel? = null
    private var initialSearchQuery: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        captureSearchIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        captureSearchIntent(intent)
    }

    private fun captureSearchIntent(intent: Intent?) {
        if (intent?.action != Intent.ACTION_SEARCH) return
        val query = intent.getStringExtra(SearchManager.QUERY)?.trim().orEmpty()
        if (query.isEmpty()) return
        if (searchChannel != null) {
            searchChannel?.invokeMethod("onSearchIntent", query)
        } else {
            initialSearchQuery = query
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        DalvikRuntimeManager.initialize(applicationContext)
        val piper = PiperMethodChannel(applicationContext)
        piper.register(
            MethodChannel(
                flutterEngine.dartExecutor.binaryMessenger,
                "com.koma.koma/piper",
            ),
        )
        piperChannel = piper
        StorageAccessChannel(this).register(
            MethodChannel(
                flutterEngine.dartExecutor.binaryMessenger,
                "com.koma.koma/storage",
            ),
        )
        searchChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.koma.koma/search",
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialSearchQuery" -> {
                        val q = initialSearchQuery
                        initialSearchQuery = null
                        result.success(q)
                    }
                    else -> result.notImplemented()
                }
            }
            initialSearchQuery?.let { q ->
                initialSearchQuery = null
                channel.invokeMethod("onSearchIntent", q)
            }
        }
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
            when (call.method) {
                "getApkSigningInfo" -> {
                    Thread {
                        try {
                            val apkPath = call.argument<String>("apkPath")
                                ?: throw IllegalArgumentException("missing apkPath")
                            val info = inspectApkSigning(apkPath)
                            runOnUiThread { result.success(info) }
                        } catch (e: Throwable) {
                            Log.e("ApkSign", "getApkSigningInfo failed", e)
                            runOnUiThread {
                                result.error("APK_SIGN", e.message, null)
                            }
                        }
                    }.start()
                }
                "installApk" -> {
                    try {
                        val apkPath = call.argument<String>("apkPath")
                            ?: throw IllegalArgumentException("missing apkPath")
                        installApkUpdate(apkPath)
                        result.success(null)
                    } catch (e: Throwable) {
                        Log.e("AppUpdate", "installApk failed", e)
                        result.error("INSTALL_APK", e.message, null)
                    }
                }
                "getDeviceConstraints" -> {
                    result.success(readDeviceConstraints())
                }
                "installApkViaPackageInstaller" -> {
                    Thread {
                        try {
                            val apkPath = call.argument<String>("apkPath")
                                ?: throw IllegalArgumentException("missing apkPath")
                            PackageInstallerHelper.install(applicationContext, apkPath)
                            runOnUiThread { result.success(null) }
                        } catch (e: Throwable) {
                            Log.e("PkgInstaller", "install failed", e)
                            runOnUiThread {
                                result.error("PKG_INSTALL", e.message, null)
                            }
                        }
                    }.start()
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.koma.koma/media",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "saveToGallery" -> {
                    Thread {
                        try {
                            val bytes = coerceByteArray(call.argument("bytes"))
                                ?: throw IllegalArgumentException("missing bytes")
                            val displayName = call.argument<String>("displayName")
                                ?: "koma_image.jpg"
                            val album = call.argument<String>("albumSubfolder")
                            val mime = call.argument<String>("mimeType") ?: "image/jpeg"
                            val uri = saveImageToGallery(bytes, displayName, album, mime)
                            runOnUiThread {
                                if (uri != null) result.success(uri.toString())
                                else result.error("SAVE_FAILED", "MediaStore insert failed", null)
                            }
                        } catch (e: Throwable) {
                            Log.e("MediaExport", "saveToGallery failed", e)
                            runOnUiThread {
                                result.error("SAVE_FAILED", e.message, null)
                            }
                        }
                    }.start()
                }
                "shareImage" -> {
                    try {
                        val bytes = coerceByteArray(call.argument("bytes"))
                            ?: throw IllegalArgumentException("missing bytes")
                        val displayName = call.argument<String>("displayName")
                            ?: "koma_image.jpg"
                        val mime = call.argument<String>("mimeType") ?: "image/jpeg"
                        shareImageBytes(bytes, displayName, mime)
                        result.success(null)
                    } catch (e: Throwable) {
                        Log.e("MediaExport", "shareImage failed", e)
                        result.error("SHARE_FAILED", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.koma.koma/source_prefs",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isConfigurable" -> {
                    Thread {
                        try {
                            DalvikRuntimeManager.initialize(applicationContext)
                            DalvikRuntimeManager.getOrStartServer()
                            val sourceId = call.argument<String>("sourceId") ?: ""
                            val apkPath = call.argument<String>("apkPath")
                            val server = DalvikServer.getInstance()
                            val configurable = if (!apkPath.isNullOrBlank()) {
                                server.ensureLoadedAndConfigurable(apkPath, sourceId)
                            } else {
                                server.isConfigurableSource(sourceId)
                            }
                            runOnUiThread { result.success(configurable) }
                        } catch (e: Throwable) {
                            Log.e("SourcePrefs", "isConfigurable failed", e)
                            runOnUiThread { result.success(false) }
                        }
                    }.start()
                }
                "openSourcePreferences" -> {
                    try {
                        val sourceId = call.argument<String>("sourceId")
                            ?: throw IllegalArgumentException("missing sourceId")
                        val apkPath = call.argument<String>("apkPath")
                        val title = call.argument<String>("title")
                        Thread {
                            try {
                                DalvikRuntimeManager.initialize(applicationContext)
                                DalvikRuntimeManager.getOrStartServer()
                                val server = DalvikServer.getInstance()
                                if (!apkPath.isNullOrBlank()) {
                                    server.ensureLoadedAndConfigurable(apkPath, sourceId)
                                }
                                runOnUiThread {
                                    startActivity(
                                        SourcePreferencesActivity.intent(
                                            this,
                                            sourceId,
                                            title,
                                        ),
                                    )
                                    result.success(null)
                                }
                            } catch (e: Throwable) {
                                Log.e("SourcePrefs", "openSourcePreferences failed", e)
                                runOnUiThread {
                                    result.error("PREFS_FAILED", e.message, null)
                                }
                            }
                        }.start()
                    } catch (e: Throwable) {
                        result.error("PREFS_FAILED", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.koma.koma/webview",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "openWebView" -> {
                    try {
                        val url = call.argument<String>("url")
                            ?: throw IllegalArgumentException("missing url")
                        val sourceId = call.argument<String>("sourceId")
                        val title = call.argument<String>("title")
                        val memo = call.argument<String>("memo")
                        startActivity(
                            SourceWebViewActivity.intent(
                                this,
                                url,
                                sourceId,
                                title,
                                memo,
                            ),
                        )
                        result.success(null)
                    } catch (e: Throwable) {
                        Log.e("SourceWebView", "openWebView failed", e)
                        result.error("WEBVIEW_FAILED", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun readDeviceConstraints(): Map<String, Any> {
        val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val network = cm.activeNetwork
        val caps = network?.let { cm.getNetworkCapabilities(it) }
        val unmetered = caps?.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_METERED) == true
        val bm = getSystemService(Context.BATTERY_SERVICE) as BatteryManager
        val charging = bm.isCharging
        return mapOf("unmetered" to unmetered, "charging" to charging)
    }

    private fun coerceByteArray(raw: Any?): ByteArray? = when (raw) {
        null -> null
        is ByteArray -> raw
        is List<*> -> ByteArray(raw.size) { i ->
            when (val v = raw[i]) {
                is Number -> v.toByte()
                else -> 0
            }
        }
        else -> null
    }

    /**
     * Mihon ImageSaver pattern: MediaStore insert under Pictures/Koma on
     * API 29+, legacy public Pictures write + media scan below that.
     * Do not use IS_PENDING (Mihon doesn't) — it left files invisible on some OEMs.
     */
    private fun saveImageToGallery(
        bytes: ByteArray,
        displayName: String,
        albumSubfolder: String?,
        mimeType: String,
    ): Uri? {
        var safeName = sanitizeFilename(displayName)
        if (!safeName.contains('.')) {
            safeName = when {
                mimeType.contains("png") -> "$safeName.png"
                mimeType.contains("webp") -> "$safeName.webp"
                else -> "$safeName.jpg"
            }
        }
        // Flat album — chapter names as nested folders break MediaStore inserts
        // on some devices; put everything in Pictures/Koma/.
        val relativePath = Environment.DIRECTORY_PICTURES + "/Koma"

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.Images.Media.DISPLAY_NAME, safeName)
                put(MediaStore.Images.Media.MIME_TYPE, mimeType)
                put(MediaStore.Images.Media.RELATIVE_PATH, relativePath)
            }
            val resolver = contentResolver
            // Prefer EXTERNAL (not PRIMARY-only) — more reliable across OEMs.
            val collection = MediaStore.Images.Media.EXTERNAL_CONTENT_URI
            val uri = resolver.insert(collection, values) ?: return null
            try {
                resolver.openOutputStream(uri)?.use { out ->
                    out.write(bytes)
                    out.flush()
                } ?: run {
                    resolver.delete(uri, null, null)
                    return null
                }
            } catch (e: Throwable) {
                Log.e("MediaExport", "write failed", e)
                runCatching { resolver.delete(uri, null, null) }
                return null
            }
            return uri
        }

        @Suppress("DEPRECATION")
        val dir = File(
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES),
            "Koma",
        )
        if (!dir.exists() && !dir.mkdirs()) return null
        val file = File(dir, safeName)
        FileOutputStream(file).use { it.write(bytes) }
        MediaScannerConnection.scanFile(
            this,
            arrayOf(file.absolutePath),
            arrayOf(mimeType),
            null,
        )
        @Suppress("DEPRECATION")
        val values = ContentValues().apply {
            put(MediaStore.Images.Media.DATA, file.absolutePath)
            put(MediaStore.Images.Media.MIME_TYPE, mimeType)
            put(MediaStore.Images.Media.DISPLAY_NAME, safeName)
        }
        return contentResolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
            ?: Uri.fromFile(file)
    }

    /**
     * Mihon [NewUpdateScreenModel.installUpdate] parity — open the system
     * package installer for a downloaded APK via FileProvider.
     */
    private fun installApkUpdate(apkPath: String) {
        val file = File(apkPath)
        if (!file.exists()) throw IllegalArgumentException("apk not found: $apkPath")
        val uri = FileProvider.getUriForFile(
            this,
            "${applicationContext.packageName}.fileprovider",
            file,
        )
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_GRANT_READ_URI_PERMISSION
        }
        startActivity(intent)
    }

    private fun shareImageBytes(bytes: ByteArray, displayName: String, mimeType: String) {
        val shareDir = File(cacheDir, "share").also { it.mkdirs() }
        val file = File(shareDir, sanitizeFilename(displayName))
        FileOutputStream(file).use { it.write(bytes) }
        val uri = FileProvider.getUriForFile(
            this,
            "${applicationContext.packageName}.fileprovider",
            file,
        )
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = mimeType
            putExtra(Intent.EXTRA_STREAM, uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        startActivity(Intent.createChooser(intent, null))
    }

    private fun sanitizeFilename(name: String): String {
        val cleaned = name
            .replace(Regex("[\\\\/:*?\"<>|]"), "_")
            .trim()
            .trimStart('.')
        return cleaned.ifEmpty { "koma_image.jpg" }.take(200)
    }

    /**
     * Mihon [ExtensionLoader.getSignatures] parity for private APK archives.
     * Returns packageName, versionName, versionCode, and SHA-256 signature digests.
     */
    private fun inspectApkSigning(apkPath: String): Map<String, Any?> {
        val file = File(apkPath)
        if (!file.exists()) throw IllegalArgumentException("apk not found: $apkPath")

        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            PackageManager.GET_SIGNING_CERTIFICATES
        } else {
            @Suppress("DEPRECATION")
            PackageManager.GET_SIGNATURES
        }
        val pkgInfo: PackageInfo = packageManager.getPackageArchiveInfo(apkPath, flags)
            ?: throw IllegalStateException("failed to parse APK: $apkPath")

        val signatures = mutableListOf<String>()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val signingInfo = pkgInfo.signingInfo
            val certs = when {
                signingInfo == null -> emptyArray()
                signingInfo.hasMultipleSigners() -> signingInfo.apkContentsSigners
                else -> signingInfo.signingCertificateHistory
            }
            for (sig in certs) {
                signatures += sha256Hex(sig.toByteArray())
            }
        } else {
            @Suppress("DEPRECATION")
            for (sig in pkgInfo.signatures.orEmpty()) {
                signatures += sha256Hex(sig.toByteArray())
            }
        }

        return mapOf(
            "packageName" to (pkgInfo.packageName ?: ""),
            "versionName" to (pkgInfo.versionName ?: ""),
            "versionCode" to PackageInfoCompat.getLongVersionCode(pkgInfo),
            "signatures" to signatures,
        )
    }

    private fun sha256Hex(bytes: ByteArray): String {
        val digest = MessageDigest.getInstance("SHA-256").digest(bytes)
        val chars = CharArray(digest.size * 2)
        val hex = "0123456789abcdef"
        var j = 0
        for (b in digest) {
            val v = b.toInt() and 0xff
            chars[j++] = hex[v ushr 4]
            chars[j++] = hex[v and 0x0f]
        }
        return String(chars)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        // The runtime is process-scoped (DalvikRuntimeManager): it must survive
        // the Activity's engine so background WorkManager tasks can reuse it.
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
