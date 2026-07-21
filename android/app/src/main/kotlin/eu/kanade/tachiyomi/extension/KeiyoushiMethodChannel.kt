package eu.kanade.tachiyomi.extension

import android.content.Context
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
import android.util.Log
import eu.kanade.tachiyomi.source.model.Page
import eu.kanade.tachiyomi.source.model.toMap
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlin.concurrent.thread

/**
 * Bridges Dart ↔ Kotlin for Keiyoushi extension operations.
 *
 * Channel name: `eu.kanade.tachiyomi/keiyoushi`
 *
 * Inbound methods (Dart → Kotlin):
 *   - `loadExtension({ apkPath, className })`            → { id, name, lang, apkPath, className }
 *   - `unloadExtension({ sourceId })`                   → null
 *   - `listLoadedExtensions()`                          → List<Map>
 *   - `getPopularManga({ sourceId, page })`             → { mangas: [...], hasNextPage: bool }
 *   - `searchManga({ sourceId, query, page })`          → { mangas: [...], hasNextPage: bool }
 *   - `getMangaDetails({ sourceId, url })`              → { ...SManga fields... }
 *   - `getChapterList({ sourceId, url })`               → List<Map>
 *   - `getPageList({ sourceId, url })`                  → List<Map>
 *   - `searchAllInstalled({ query, page })`             → List<{ sourceId, sourceName, mangas, hasNextPage }>
 */
class KeiyoushiMethodChannel(
    private val context: Context,
    private val engine: KeiyoushiEngine = KeiyoushiEngine(context),
) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "eu.kanade.tachiyomi/keiyoushi"
        private const val TAG = "KeiyoushiMC"
    }

    private val mainHandler = Handler(Looper.getMainLooper())

    /**
     * Read the `<meta-data android:name="tachiyomi.extension.class">` tag
     * from a Keiyoushi APK's manifest, if present. Returns the FQN of
     * the main Source class so the Dart side doesn't have to ask the
     * user for it.
     */
    private fun extractMainClass(apkPath: String): String? {
        val pm = context.packageManager
        val info = pm.getPackageArchiveInfo(
            apkPath,
            PackageManager.GET_META_DATA,
        ) ?: return null
        info.applicationInfo?.sourceDir = apkPath
        val meta = info.applicationInfo?.metaData ?: return null
        return meta.getString("tachiyomi.extension.class")
    }

    /** Run [block] on a background thread, deliver [onResult] on main; report errors to [result]. */
    private fun <T> bg(block: () -> T, result: MethodChannel.Result, onResult: (T) -> Unit) {
        thread {
            try {
                val value = block()
                mainHandler.post { onResult(value) }
            } catch (e: Throwable) {
                Log.e(TAG, "bg error", e)
                mainHandler.post {
                    result.error(
                        "KEIYOUSHI",
                        "${e.javaClass.simpleName}: ${e.message}",
                        e.stackTraceToString(),
                    )
                }
            }
        }
    }

    /** Register this handler on the given Flutter engine. Call from
     *  [MainActivity.configureFlutterEngine]. */
    fun registerOn(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        Log.d(TAG, "onMethodCall: method=${call.method} args=${call.arguments}")

        try {
            when (call.method) {
                "loadExtension" -> {
                    val apkPath = call.argument<String>("apkPath")
                    if (apkPath == null) {
                        Log.e(TAG, "loadExtension: apkPath missing")
                        result.error("ARG", "apkPath missing", null)
                        return
                    }
                    Log.d(TAG, "loadExtension: apkPath=$apkPath")

                    val className = call.argument<String>("className")
                        ?: extractMainClass(apkPath)
                        ?: run {
                            Log.e(TAG, "loadExtension: no className for $apkPath")
                            result.error(
                                "NOCLASS",
                                "No className supplied and APK manifest " +
                                    "has no tachiyomi.extension.class meta-data",
                                null,
                            )
                            return
                        }
                    Log.d(TAG, "loadExtension: className=$className")

                    bg({ engine.loadExtension(apkPath, className) }, result) { desc ->
                        Log.d(TAG, "loadExtension: success → $desc")
                        result.success(desc)
                    }
                }
                "unloadExtension" -> {
                    val sourceId = call.argument<String>("sourceId")
                    if (sourceId == null) {
                        Log.e(TAG, "unloadExtension: sourceId missing")
                        result.error("ARG", "sourceId missing", null)
                        return
                    }
                    Log.d(TAG, "unloadExtension: sourceId=$sourceId")
                    bg({ engine.unloadExtension(sourceId) }, result) {
                        result.success(null)
                    }
                }
                "listLoadedExtensions" -> {
                    val list = engine.listLoaded()
                    Log.d(TAG, "listLoadedExtensions: ${list.size} loaded")
                    result.success(list)
                }
                "getPopularManga" -> {
                    val sourceId = call.argument<String>("sourceId")
                    if (sourceId == null) {
                        Log.e(TAG, "getPopularManga: sourceId missing")
                        result.error("ARG", "sourceId missing", null)
                        return
                    }
                    val page = call.argument<Int>("page") ?: 1
                    Log.d(TAG, "getPopularManga: sourceId=$sourceId page=$page")
                    bg({ engine.getPopularManga(sourceId, page) }, result) { mangasPage ->
                        result.success(
                            mapOf(
                                "mangas" to mangasPage.mangas.map { it.toMap() },
                                "hasNextPage" to mangasPage.hasNextPage,
                            )
                        )
                    }
                }
                "searchManga" -> {
                    val sourceId = call.argument<String>("sourceId")
                    if (sourceId == null) {
                        Log.e(TAG, "searchManga: sourceId missing")
                        result.error("ARG", "sourceId missing", null)
                        return
                    }
                    val query = call.argument<String>("query") ?: ""
                    val page = call.argument<Int>("page") ?: 1
                    Log.d(TAG, "searchManga: sourceId=$sourceId query=$query page=$page")
                    bg({ engine.searchManga(sourceId, query, page) }, result) { mangasPage ->
                        result.success(
                            mapOf(
                                "mangas" to mangasPage.mangas.map { it.toMap() },
                                "hasNextPage" to mangasPage.hasNextPage,
                            )
                        )
                    }
                }
                "getMangaDetails" -> {
                    val sourceId = call.argument<String>("sourceId")
                    val url = call.argument<String>("url")
                    if (sourceId == null) {
                        Log.e(TAG, "getMangaDetails: sourceId missing")
                        result.error("ARG", "sourceId missing", null)
                        return
                    }
                    if (url == null) {
                        Log.e(TAG, "getMangaDetails: url missing")
                        result.error("ARG", "url missing", null)
                        return
                    }
                    Log.d(TAG, "getMangaDetails: sourceId=$sourceId url=$url")
                    bg({ engine.getMangaDetails(sourceId, url) }, result) { manga ->
                        result.success(manga.toMap())
                    }
                }
                "getChapterList" -> {
                    val sourceId = call.argument<String>("sourceId")
                    val url = call.argument<String>("url")
                    if (sourceId == null) {
                        Log.e(TAG, "getChapterList: sourceId missing")
                        result.error("ARG", "sourceId missing", null)
                        return
                    }
                    if (url == null) {
                        Log.e(TAG, "getChapterList: url missing")
                        result.error("ARG", "url missing", null)
                        return
                    }
                    Log.d(TAG, "getChapterList: sourceId=$sourceId")
                    bg({ engine.getChapterList(sourceId, url) }, result) { chapters ->
                        result.success(chapters.map { it.toMap() })
                    }
                }
                "getPageList" -> {
                    val sourceId = call.argument<String>("sourceId")
                    val url = call.argument<String>("url")
                    if (sourceId == null) {
                        Log.e(TAG, "getPageList: sourceId missing")
                        result.error("ARG", "sourceId missing", null)
                        return
                    }
                    if (url == null) {
                        Log.e(TAG, "getPageList: url missing")
                        result.error("ARG", "url missing", null)
                        return
                    }
                    Log.d(TAG, "getPageList: sourceId=$sourceId")
                    bg({ engine.getPageList(sourceId, url) }, result) { pages ->
                        result.success(pages)
                    }
                }
                "searchAllInstalled" -> {
                    val query = call.argument<String>("query") ?: ""
                    val page = call.argument<Int>("page") ?: 1
                    Log.d(TAG, "searchAllInstalled: query=$query page=$page")
                    bg({ engine.searchAllInstalled(query, page) }, result) { list ->
                        result.success(list)
                    }
                }
                "downloadChapters" -> {
                    val sourceId = call.argument<String>("sourceId")
                    val mangaUrl = call.argument<String>("mangaUrl")
                    val chapterUrls = call.argument<List<String>>("chapterUrls")
                    val chapterNames = call.argument<List<String>>("chapterNames")
                    if (sourceId == null || mangaUrl == null || chapterUrls == null) {
                        result.error("ARG", "Missing required arguments", null)
                        return
                    }
                    Log.d(TAG, "downloadChapters: sourceId=$sourceId chapters=${chapterUrls.size}")
                    bg({
                        engine.downloadChapters(sourceId, mangaUrl, chapterUrls, chapterNames ?: emptyList())
                    }, result) { map ->
                        result.success(map)
                    }
                }
                "getLocalPages" -> {
                    val sourceId = call.argument<String>("sourceId") ?: ""
                    val mangaUrl = call.argument<String>("mangaUrl") ?: ""
                    val chapterUrl = call.argument<String>("chapterUrl") ?: ""
                    Log.d(TAG, "getLocalPages: sourceId=$sourceId chapterUrl=$chapterUrl")
                    result.success(engine.getLocalPages(sourceId, mangaUrl, chapterUrl))
                }
                "getDownloadedChapterKeys" -> {
                    val sourceId = call.argument<String>("sourceId") ?: ""
                    val mangaUrl = call.argument<String>("mangaUrl") ?: ""
                    Log.d(TAG, "getDownloadedChapterKeys: sourceId=$sourceId")
                    result.success(engine.getDownloadedChapterKeys(sourceId, mangaUrl))
                }
                else -> {
                    Log.w(TAG, "Unimplemented method: ${call.method}")
                    result.notImplemented()
                }
            }
        } catch (e: Throwable) {
            Log.e(TAG, "onMethodCall error: method=${call.method}", e)
            val msg = "${e.javaClass.simpleName}: ${e.message}"
            result.error("KEIYOUSHI", msg, e.stackTraceToString())
        }
    }
}
