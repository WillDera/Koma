package eu.kanade.tachiyomi.extension

import android.content.Context
import eu.kanade.tachiyomi.source.model.Page
import eu.kanade.tachiyomi.source.model.toMap
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import android.content.pm.PackageManager

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
 */
class KeiyoushiMethodChannel(
    private val context: Context,
    private val engine: KeiyoushiEngine = KeiyoushiEngine(context),
) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "eu.kanade.tachiyomi/keiyoushi"
    }

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
        // Without this, resources won't resolve correctly. Doesn't
        // matter for us — we only want raw meta-data.
        info.applicationInfo?.sourceDir = apkPath
        val meta = info.applicationInfo?.metaData ?: return null
        return meta.getString("tachiyomi.extension.class")
    }

    /** Register this handler on the given Flutter engine. Call from
     *  [MainActivity.configureFlutterEngine]. */
    fun registerOn(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "loadExtension" -> {
                    val apkPath = call.argument<String>("apkPath")
                    if (apkPath == null) {
                        result.error("ARG", "apkPath missing", null)
                        return
                    }
                    // If Dart didn't supply a class name, try to pull it
                    // from the APK's manifest. Fall back to the engine
                    // throwing a clear error if neither is present.
                    val className = call.argument<String>("className")
                        ?: extractMainClass(apkPath)
                        ?: run {
                            result.error(
                                "NOCLASS",
                                "No className supplied and APK manifest " +
                                    "has no tachiyomi.extension.class meta-data",
                                null,
                            )
                            return
                        }
                    result.success(engine.loadExtension(apkPath, className))
                }
                "unloadExtension" -> {
                    val sourceId = call.argument<String>("sourceId")
                    if (sourceId == null) {
                        result.error("ARG", "sourceId missing", null)
                        return
                    }
                    engine.unloadExtension(sourceId)
                    result.success(null)
                }
                "listLoadedExtensions" -> {
                    result.success(engine.listLoaded())
                }
                "getPopularManga" -> {
                    val sourceId = call.argument<String>("sourceId")
                    if (sourceId == null) {
                        result.error("ARG", "sourceId missing", null)
                        return
                    }
                    val page = call.argument<Int>("page") ?: 1
                    val mangasPage = engine.getPopularManga(sourceId, page)
                    result.success(
                        mapOf(
                            "mangas" to mangasPage.mangas.map { it.toMap() },
                            "hasNextPage" to mangasPage.hasNextPage,
                        )
                    )
                }
                "searchManga" -> {
                    val sourceId = call.argument<String>("sourceId")
                    if (sourceId == null) {
                        result.error("ARG", "sourceId missing", null)
                        return
                    }
                    val query = call.argument<String>("query") ?: ""
                    val page = call.argument<Int>("page") ?: 1
                    val mangasPage = engine.searchManga(sourceId, query, page)
                    result.success(
                        mapOf(
                            "mangas" to mangasPage.mangas.map { it.toMap() },
                            "hasNextPage" to mangasPage.hasNextPage,
                        )
                    )
                }
                "getMangaDetails" -> {
                    val sourceId = call.argument<String>("sourceId")
                    val url = call.argument<String>("url")
                    if (sourceId == null) {
                        result.error("ARG", "sourceId missing", null)
                        return
                    }
                    if (url == null) {
                        result.error("ARG", "url missing", null)
                        return
                    }
                    val manga = engine.getMangaDetails(sourceId, url)
                    result.success(manga.toMap())
                }
                "getChapterList" -> {
                    val sourceId = call.argument<String>("sourceId")
                    val url = call.argument<String>("url")
                    if (sourceId == null) {
                        result.error("ARG", "sourceId missing", null)
                        return
                    }
                    if (url == null) {
                        result.error("ARG", "url missing", null)
                        return
                    }
                    val chapters = engine.getChapterList(sourceId, url)
                    result.success(chapters.map { it.toMap() })
                }
                "getPageList" -> {
                    val sourceId = call.argument<String>("sourceId")
                    val url = call.argument<String>("url")
                    if (sourceId == null) {
                        result.error("ARG", "sourceId missing", null)
                        return
                    }
                    if (url == null) {
                        result.error("ARG", "url missing", null)
                        return
                    }
                    val pages: List<Page> = engine.getPageList(sourceId, url)
                    result.success(pages.map { it.toMap() })
                }
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("KEIYOUSHI", e.message ?: e.javaClass.simpleName, e.stackTraceToString())
        }
    }
}
