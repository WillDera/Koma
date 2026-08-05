package eu.kanade.tachiyomi.extension

import android.app.Application
import android.content.Context
import android.content.pm.PackageManager
import android.util.Base64
import android.util.Log
import eu.kanade.tachiyomi.network.NetworkHelper
import eu.kanade.tachiyomi.network.defaultClient
import eu.kanade.tachiyomi.source.ConfigurableSource
import eu.kanade.tachiyomi.source.Source
import eu.kanade.tachiyomi.source.SourceFactory
import eu.kanade.tachiyomi.source.model.Filter
import eu.kanade.tachiyomi.source.model.FilterList
import eu.kanade.tachiyomi.source.model.MangasPage
import eu.kanade.tachiyomi.source.model.Page
import eu.kanade.tachiyomi.source.model.SChapter
import eu.kanade.tachiyomi.source.model.SManga
import eu.kanade.tachiyomi.source.model.toMap
import eu.kanade.tachiyomi.source.online.HttpSource
import eu.kanade.tachiyomi.util.system.ChildFirstPathClassLoader
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.put
import mihon.core.common.extensions.EMPTY
import okhttp3.OkHttpClient
import uy.kohesive.injekt.Injekt
import uy.kohesive.injekt.api.InjektModule
import uy.kohesive.injekt.api.InjektRegistrar
import uy.kohesive.injekt.api.addSingleton
import uy.kohesive.injekt.api.addSingletonFactory
import uy.kohesive.injekt.api.get
import java.io.BufferedReader
import java.io.File
import java.io.IOException
import java.io.InputStreamReader
import java.io.OutputStream
import java.net.ServerSocket
import java.net.Socket
import java.nio.charset.StandardCharsets
import java.security.MessageDigest

class DalvikServer(
    private val context: Context,
) {
    companion object {
        private const val TAG = "DalvikServer"
        private val SUPPORTED_LIB_VERSIONS = listOf(1.4, 1.6)
        @Volatile
        private var instance: DalvikServer? = null

        fun getInstance(): DalvikServer =
            instance ?: throw IllegalStateException("DalvikServer not initialized")

        fun initialize(context: Context): DalvikServer = instance ?: synchronized(this) {
            instance ?: DalvikServer(context).also { instance = it }
        }
    }

    private var injected = false
    private val json = Json { ignoreUnknownKeys = true; isLenient = true }
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private var serverSocket: ServerSocket? = null
    private var isRunning = false
    private var _port = -1

    val port: Int get() = _port

    // -- Stateful extension cache ----------------------------------------------

    private data class LoadedExtension(
        val sourceId: String,
        val source: HttpSource,
        val apkPath: String,
        val loadedAt: Long,
    )

    private val loadedExtensions = mutableMapOf<String, LoadedExtension>()
    private val loadedApkPaths = mutableMapOf<String, File>()
    private val extensionsCacheDir: File by lazy {
        File(context.cacheDir, "dex-extensions").also { it.mkdirs() }
    }

    /**
     * Looks up a loaded [HttpSource] by hex bridge id or Mihon numeric
     * [Source.id]. Used by SourcePreferencesActivity (outside the TCP API).
     */
    fun findHttpSource(sourceId: String): HttpSource? {
        if (sourceId.isBlank()) return null
        loadedExtensions[sourceId]?.source?.let { return it }
        for ((_, candidate) in loadedExtensions) {
            if (candidate.source.id.toString() == sourceId) return candidate.source
        }
        return null
    }

    fun isConfigurableSource(sourceId: String): Boolean =
        findHttpSource(sourceId) is ConfigurableSource

    /**
     * Load (or reuse) an extension APK and return whether the resulting source
     * implements [ConfigurableSource].
     */
    @Synchronized
    fun ensureLoadedAndConfigurable(apkPath: String, preferredSourceId: String? = null): Boolean {
        ensureInjekt()
        val apkFile = File(apkPath)
        if (!apkFile.exists()) return false
        // Prefer existing entry matching path or preferred id.
        if (preferredSourceId != null) {
            findHttpSource(preferredSourceId)?.let { return it is ConfigurableSource }
        }
        for ((_, ext) in loadedExtensions) {
            if (ext.apkPath == apkPath) return ext.source is ConfigurableSource
        }
        return try {
            val root = buildJsonObject {
                put("apkPath", apkPath)
            }
            val resp = handleLoadExtension(root)
            val parsed = json.parseToJsonElement(resp) as? JsonObject ?: return false
            if (parsed.containsKey("error")) return false
            val sid = (parsed["sourceId"] as? JsonPrimitive)?.content
                ?: preferredSourceId
                ?: return false
            findHttpSource(sid) is ConfigurableSource
        } catch (e: Exception) {
            Log.e(TAG, "ensureLoadedAndConfigurable failed", e)
            false
        }
    }

    @Synchronized
    fun start(): Int {
        if (isRunning) return _port
        ensureInjekt()
        serverSocket = ServerSocket(0)
        _port = serverSocket!!.localPort
        isRunning = true
        Log.d(TAG, "start: listening on port $_port")
        scope.launch {
            while (isRunning) {
                try {
                    val client = serverSocket?.accept() ?: break
                    Log.d(TAG, "start: accepted connection")
                    scope.launch { handleClient(client) }
                } catch (e: Throwable) {
                    Log.e(TAG, "start: accept loop caught", e)
                    break
                }
            }
            Log.d(TAG, "start: accept loop ended, isRunning=$isRunning")
        }
        return _port
    }

    // Same monitor as [start]: callers (e.g. DalvikRuntimeManager restart)
    // must not race mutations of isRunning / serverSocket / _port.
    @Synchronized
    fun stop() {
        isRunning = false
        try {
            serverSocket?.close()
        } catch (_: Throwable) {
        }
        serverSocket = null
        _port = -1
    }

    // -- Injekt init (once) ------------------------------------------------

    private fun ensureInjekt() {
        if (injected) return
        injected = true
        val app = context.applicationContext as Application
        Injekt.importModule(object : InjektModule {
            override fun InjektRegistrar.registerInjectables() {
                addSingleton(app)
                addSingletonFactory { defaultClient(context) }
                addSingletonFactory {
                    Json { ignoreUnknownKeys = true; explicitNulls = false; isLenient = true }
                }
                addSingletonFactory { NetworkHelper(Injekt.get<OkHttpClient>()) }
            }
        })
    }

    // -- Stateful extension registry (primary path) ------------------------

    private fun handleLoadExtension(root: JsonObject): String {
        val apkPath = root.str("apkPath") ?: return errorJson("missing apkPath")
        val className = root.str("className")
        val apkFile = File(apkPath)
        if (!apkFile.exists()) return errorJson("apk not found: $apkPath")

        val sourceId = sha256(apkPath).take(16)

        // Copy to read-only cache dir so Android 14+ allows DexClassLoader
        val cachedApk = File(extensionsCacheDir, "$sourceId.apk")
        if (!cachedApk.exists() || cachedApk.length() != apkFile.length()) {
            cachedApk.delete()
            cachedApk.parentFile?.mkdirs()
            apkFile.copyTo(cachedApk, overwrite = true)
            cachedApk.setReadOnly()
        }
        loadedApkPaths[sourceId] = cachedApk

        val source = try {
            loadSource(cachedApk)
        } catch (e: Throwable) {
            Log.e(TAG, "loadExtension: failed", e)
            cachedApk.delete()
            loadedApkPaths.remove(sourceId)
            return errorJson("loadExtension failed: ${e.message}")
        }
        if (source !is HttpSource) {
            return errorJson("not HttpSource: ${source.javaClass.name}")
        }

        loadedExtensions[sourceId] = LoadedExtension(
            sourceId = sourceId,
            source = source,
            apkPath = cachedApk.absolutePath,
            loadedAt = System.currentTimeMillis(),
        )
        Log.d(TAG, "loadExtension: cached sourceId=$sourceId name=${source.name}")

        return json.encodeToString(buildJsonObject {
            put("sourceId", sourceId)
            put("id", source.id.toString())
            put("name", source.name)
            put("lang", source.lang)
            put("baseUrl", source.baseUrl)
            if (className != null) put("className", className)
        })
    }

    private fun handleUnloadExtension(root: JsonObject): String {
        val sourceId = root.str("sourceId") ?: return errorJson("missing sourceId")
        val removed = loadedExtensions.remove(sourceId)
        loadedApkPaths.remove(sourceId)?.delete()
        Log.d(TAG, "unloadExtension: sourceId=$sourceId removed=${removed != null}")
        return json.encodeToString(
            buildJsonObject {
                put("sourceId", sourceId)
                put("unloaded", removed != null)
            }
        )
    }

    private fun handleListLoadedExtensions(): String {
        val list = loadedExtensions.values.map { ext ->
            buildJsonObject {
                put("sourceId", ext.sourceId)
                put("id", ext.source.id.toString())
                put("name", ext.source.name)
                put("lang", ext.source.lang)
                put("baseUrl", ext.source.baseUrl)
                put("apkPath", ext.apkPath)
                put("loadedAt", ext.loadedAt)
            }
        }
        return json.encodeToString(JsonArray(list))
    }

    // -- Fallback per-request extension loading (base64 APK) ----------------

    private fun <T> withSource(base64Apk: String, block: (HttpSource) -> T): T {
        val apkBytes = Base64.decode(base64Apk, Base64.DEFAULT)
        val tempFile = File.createTempFile("ext", ".apk", context.cacheDir)
        try {
            tempFile.writeBytes(apkBytes)
            tempFile.setReadOnly()
            val source = loadSource(tempFile)
            if (source !is HttpSource) {
                throw IllegalArgumentException("Source is not HttpSource: ${source.javaClass.name}")
            }
            return block(source)
        } finally {
            if (tempFile.exists()) tempFile.delete()
        }
    }

    // -- Unified source resolver (stateful first, stateless fallback) -------

    private fun <T> withLoadedExtension(
        sourceId: String?,
        base64Apk: String?,
        block: (HttpSource) -> T,
    ): T {
        if (sourceId != null) {
            val ext = loadedExtensions[sourceId]
            if (ext != null) {
                Log.d(TAG, "withLoadedExtension: cache hit sourceId=$sourceId")
                return block(ext.source)
            }
            // Fallback: match by Mihon numeric ID (source.id.toString()) for
            // callers that only have the old numeric ID from the Manga model.
            for ((_, candidate) in loadedExtensions) {
                if (candidate.source.id.toString() == sourceId) {
                    Log.d(TAG, "withLoadedExtension: matched by Mihon id sourceId=$sourceId -> hex=${candidate.sourceId}")
                    return block(candidate.source)
                }
            }
            Log.w(TAG, "withLoadedExtension: source not loaded sourceId=$sourceId")
            throw IllegalStateException("Source not loaded: $sourceId — call loadExtension first")
        }
        if (base64Apk != null) {
            Log.d(TAG, "withLoadedExtension: base64 fallback")
            return withSource(base64Apk, block)
        }
        throw IllegalArgumentException("missing sourceId or data")
    }

    private fun loadSource(apkFile: File): Source {
        val apkPath = apkFile.absolutePath
        val className = resolveExtensionClass(apkFile)
        Log.d(TAG, "loadSource: apkPath=$apkPath className=$className")

        val resolvedClassName = if (className.startsWith(".")) {
            val pkg = context.packageManager.getPackageArchiveInfo(apkPath, 0)?.packageName
                ?: throw IllegalArgumentException("Cannot resolve relative class name: $className")
            val resolved = pkg + className
            Log.d(TAG, "Resolved relative class: $className -> $resolved")
            resolved
        } else {
            className
        }

        val pkgInfo = context.packageManager.getPackageArchiveInfo(apkPath, 0)
        if (pkgInfo != null) {
            val vName = pkgInfo.versionName
            Log.d(TAG, "Extension: ${pkgInfo.packageName} versionName=$vName")
            if (vName != null) {
                val libVer = vName.substringBeforeLast('.').toDoubleOrNull()
                if (libVer != null && libVer !in SUPPORTED_LIB_VERSIONS) {
                    Log.w(TAG, "Lib version $libVer out of range $SUPPORTED_LIB_VERSIONS")
                }
            }
        }

        val classLoader = try {
            ChildFirstPathClassLoader(apkPath, null, context.classLoader)
                .also { Log.d(TAG, "Created ChildFirstPathClassLoader") }
        } catch (e: Exception) {
            throw RuntimeException("Failed to create classloader for $apkPath", e)
        }

        val clazz = try {
            classLoader.loadClass(resolvedClassName)
        } catch (e: Throwable) {
            Log.e(TAG, "Failed to load class $resolvedClassName", e)
            throw e
        }
        Log.d(TAG, "Loaded class: ${clazz.name}")

        val instance = try {
            clazz.getDeclaredConstructor().newInstance()
        } catch (e: Throwable) {
            Log.e(TAG, "Failed to instantiate $resolvedClassName", e)
            throw e
        }
        Log.d(TAG, "Instantiated: ${instance.javaClass.name}")

        return when (instance) {
            is SourceFactory -> {
                val sources = instance.createSources()
                if (sources.isEmpty()) throw IllegalArgumentException("SourceFactory returned empty list")
                Log.d(TAG, "SourceFactory returned ${sources.size} sources, first=${sources.first().javaClass.name}")
                sources.first()
            }
            is Source -> {
                Log.d(TAG, "Instance is Source directly")
                instance
            }
            else -> throw IllegalArgumentException(
                "Class ${instance.javaClass.name} is neither Source nor SourceFactory"
            )
        }
    }

    private fun resolveExtensionClass(apkFile: File): String {
        val pm = context.packageManager
        val info = pm.getPackageArchiveInfo(apkFile.absolutePath, PackageManager.GET_META_DATA)
            ?: throw IllegalArgumentException("No package info for ${apkFile.absolutePath}")
        info.applicationInfo?.sourceDir = apkFile.absolutePath
        val meta = info.applicationInfo?.metaData
            ?: throw IllegalArgumentException("No meta-data in ${apkFile.absolutePath}")
        return meta.getString("tachiyomi.extension.class")
            ?: meta.getString("tachiyomi.animeextension.class")
            ?: throw IllegalArgumentException("No tachiyomi.extension.class in manifest")
    }

    // -- HTTP server -------------------------------------------------------

    private fun handleClient(socket: Socket) {
        Log.d(TAG, "handleClient: accepted")
        try {
            val input = BufferedReader(InputStreamReader(socket.getInputStream(), StandardCharsets.UTF_8))
            val output: OutputStream = socket.getOutputStream()

            val requestLine = input.readLine()
            Log.d(TAG, "handleClient: requestLine=$requestLine")
            if (requestLine == null || requestLine.isEmpty()) return

            val parts = requestLine.split(" ")
            if (parts.size < 2) return
            val path = parts[1]
            if (path != "/dalvik") {
                sendResponse(output, 404, "{}")
                return
            }

            var contentLength = 0
            var line = input.readLine()
            while (line != null && line.isNotEmpty()) {
                val colonIdx = line.indexOf(':')
                if (colonIdx > 0) {
                    val key = line.substring(0, colonIdx).trim().lowercase()
                    if (key == "content-length") {
                        contentLength = line.substring(colonIdx + 1).trim().toIntOrNull() ?: 0
                    }
                }
                line = input.readLine()
            }

            val body = CharArray(contentLength)
            var read = 0
            while (read < contentLength) {
                val n = input.read(body, read, contentLength - read)
                if (n == -1) break
                read += n
            }
            val bodyStr = String(body, 0, read)

            // downloadChapters streams NDJSON progress lines; other methods
            // return a single JSON body via sendResponse.
            val streamMethod = try {
                val root = json.parseToJsonElement(bodyStr) as? JsonObject
                (root?.get("method") as? JsonPrimitive)?.content
            } catch (_: Throwable) {
                null
            }
            if (streamMethod == "downloadChapters") {
                val root = json.parseToJsonElement(bodyStr) as JsonObject
                streamDownloadChapters(output, root)
                Log.d(TAG, "handleClient: ndjson download stream finished")
            } else {
                val response = handleRequest(bodyStr)
                sendResponse(output, 200, response)
                Log.d(TAG, "handleClient: response sent")
            }
        } catch (e: Throwable) {
            Log.e(TAG, "handleClient: caught", e)
        } finally {
            try {
                socket.close()
            } catch (_: Throwable) {
            }
        }
    }

    private fun handleRequest(body: String): String {
        return try {
            val root = json.parseToJsonElement(body) as JsonObject
            val method = (root["method"] as? JsonPrimitive)?.content ?: return errorJson("missing method")
            val data = (root["data"] as? JsonPrimitive)?.content

            val result = when (method) {
                // -- Stateful lifecycle -------------------------------------------------
                "loadExtension" -> handleLoadExtension(root)
                "unloadExtension" -> handleUnloadExtension(root)
                "listLoadedExtensions" -> handleListLoadedExtensions()

                // -- Content methods (accept sourceId or base64 data fallback) ---------
                "getPopularManga" -> {
                    val page = root.int("page") ?: 1
                    withLoadedExtension(root.str("sourceId"), data) { src ->
                        val mp = runBlocking { src.getPopularManga(page) }
                        json.encodeToString(buildJsonObject {
                            put("mangas", JsonArray(mp.mangas.map { it.toMap().toJsonObject() }))
                            put("hasNextPage", mp.hasNextPage)
                        })
                    }
                }
                "getLatestUpdates" -> {
                    val page = root.int("page") ?: 1
                    withLoadedExtension(root.str("sourceId"), data) { src ->
                        val mp = runBlocking { src.getLatestUpdates(page) }
                        json.encodeToString(buildJsonObject {
                            put("mangas", JsonArray(mp.mangas.map { it.toMap().toJsonObject() }))
                            put("hasNextPage", mp.hasNextPage)
                        })
                    }
                }
                "getSearchManga", "searchManga" -> {
                    val page = root.int("page") ?: 1
                    val query = root.str("query") ?: ""
                    withLoadedExtension(root.str("sourceId"), data) { src ->
                        // Prefer the source's real FilterList (preserves custom
                        // subclasses) and apply incoming JSON state onto it.
                        val filters = try {
                            applyFilterState(src.getFilterList(), root)
                        } catch (_: AbstractMethodError) {
                            parseFilters(root)
                        }
                        val mp = try {
                            runBlocking { src.getSearchManga(page, query, filters) }
                        } catch (_: AbstractMethodError) {
                            MangasPage(emptyList(), false)
                        }
                        json.encodeToString(buildJsonObject {
                            put("mangas", JsonArray(mp.mangas.map { it.toMap().toJsonObject() }))
                            put("hasNextPage", mp.hasNextPage)
                        })
                    }
                }
                // Discover tab: fan-out search across every extension currently
                // loaded in the Dalvik cache. Returns one object per source that
                // produced at least one hit so the UI can group by sourceName.
                "searchAllInstalled" -> {
                    val page = root.int("page") ?: 1
                    val query = root.str("query") ?: ""
                    val snapshot = loadedExtensions.values.toList()
                    val results = snapshot.mapNotNull { ext ->
                        try {
                            val filters = try {
                                ext.source.getFilterList()
                            } catch (_: AbstractMethodError) {
                                FilterList()
                            } catch (_: Throwable) {
                                FilterList()
                            }
                            val mp = try {
                                runBlocking { ext.source.getSearchManga(page, query, filters) }
                            } catch (_: AbstractMethodError) {
                                MangasPage(emptyList(), false)
                            } catch (e: Exception) {
                                Log.e(TAG, "searchAllInstalled failed for ${ext.source.name}", e)
                                return@mapNotNull null
                            }
                            if (mp.mangas.isEmpty()) return@mapNotNull null
                            buildJsonObject {
                                put("sourceId", ext.sourceId)
                                put("sourceName", ext.source.name)
                                put("baseUrl", ext.source.baseUrl)
                                put("mangas", JsonArray(mp.mangas.map { it.toMap().toJsonObject() }))
                                put("hasNextPage", mp.hasNextPage)
                            }
                        } catch (e: Throwable) {
                            Log.e(TAG, "searchAllInstalled: ${ext.sourceId}", e)
                            null
                        }
                    }
                    json.encodeToString(JsonArray(results))
                }
                "getMangaDetails" -> {
                    val url = root.str("url") ?: return errorJson("missing url")
                    withLoadedExtension(root.str("sourceId"), data) { src ->
                        // Mihon parity: hydrate catalogue fields (title/memo/…) before
                        // getMangaUpdate — AllAnime and similar sources NPE on empty memo.
                        val manga = hydrateSManga(root)
                        val result = try {
                            runBlocking { src.getMangaUpdate(manga, emptyList(), fetchDetails = true, fetchChapters = false) }
                        } catch (e: Exception) {
                            Log.e(TAG, "getMangaDetails failed for $url", e)
                            return@withLoadedExtension errorJson("getMangaDetails failed: ${e.message}")
                        }
                        val details = result.manga
                        if (!details.initialized) details.initialized = true
                        json.encodeToString(details.toMap().toJsonObject())
                    }
                }
                "getMangaUpdate" -> {
                    val url = root.str("url") ?: return errorJson("missing url")
                    withLoadedExtension(root.str("sourceId"), data) { src ->
                        val manga = hydrateSManga(root)
                        val update = try {
                            runBlocking { src.getMangaUpdate(manga, emptyList(), fetchDetails = true, fetchChapters = true) }
                        } catch (e: Exception) {
                            Log.e(TAG, "getMangaUpdate failed for $url", e)
                            // Do not return a fake empty manga — Dart treats that as
                            // success and wipes the seeded catalogue title.
                            return@withLoadedExtension errorJson("getMangaUpdate failed: ${e.message}")
                        }
                        json.encodeToString(buildJsonObject {
                            put("manga", update.manga.toMap().toJsonObject())
                            put("chapters", JsonArray(update.chapters.map { it.toMap().toJsonObject() }))
                        })
                    }
                }
                "getChapterList" -> {
                    val url = root.str("url") ?: return errorJson("missing url")
                    withLoadedExtension(root.str("sourceId"), data) { src ->
                        val manga = hydrateSManga(root)
                        val update = try {
                            runBlocking { src.getMangaUpdate(manga, emptyList(), fetchDetails = false, fetchChapters = true) }
                        } catch (e: Exception) {
                            Log.e(TAG, "getChapterList failed for $url", e)
                            return@withLoadedExtension errorJson("getChapterList failed: ${e.message}")
                        }
                        json.encodeToString(JsonArray(update.chapters.map { it.toMap().toJsonObject() }))
                    }
                }
                "getPageList" -> {
                    val url = root.str("url") ?: return errorJson("missing url")
                    withLoadedExtension(root.str("sourceId"), data) { src ->
                        val chapter = SChapter.create().apply {
                            this.url = url
                            memo = root.memo()
                        }
                        val pages = runBlocking {
                            src.getPageList(chapter).map { page ->
                                val headers = try {
                                    src.getImageRequestHeaders(page).toMap()
                                } catch (_: Exception) {
                                    emptyMap<String, String>()
                                }
                                page.toMap() + ("headers" to headers)
                            }
                        }
                        json.encodeToString(pages.toJsonElement())
                    }
                }
                // downloadChapters is handled as an NDJSON stream in handleClient.
                "getLocalPages" -> {
                    val sourceId = root.str("sourceId") ?: return errorJson("missing sourceId")
                    val mangaUrl = root.str("mangaUrl") ?: return errorJson("missing mangaUrl")
                    val chapterUrl = root.str("chapterUrl") ?: return errorJson("missing chapterUrl")
                    val mangaKey = sha256(mangaUrl).take(16)
                    val chKey = sha256(chapterUrl).take(16)
                    val dir = File(context.filesDir, "manga/$sourceId/$mangaKey/$chKey")
                    val paths = if (!dir.isDirectory) emptyList()
                    else dir.listFiles()
                        ?.filter { it.isFile && it.name.endsWith(".jpg") }
                        ?.sortedBy { it.nameWithoutExtension.toIntOrNull() ?: Int.MAX_VALUE }
                        ?.map { it.absolutePath }
                        ?: emptyList()
                    json.encodeToString(paths.toJsonElement())
                }
                "deleteChapters" -> {
                    // Filesystem-only — no extension load required (Mihon
                    // DownloadManager.deleteChapters parity).
                    val sourceId = root.str("sourceId") ?: return errorJson("missing sourceId")
                    val mangaUrl = root.str("mangaUrl") ?: return errorJson("missing mangaUrl")
                    val chapterUrls = (root["chapterUrls"] as? JsonArray)
                        ?.map { (it as? JsonPrimitive)?.content ?: "" }
                        ?.filter { it.isNotBlank() }
                        ?: emptyList()
                    val mangaKey = sha256(mangaUrl).take(16)
                    val mangaDir = File(context.filesDir, "manga/$sourceId/$mangaKey")
                    val deleted = mutableListOf<String>()
                    for (chapterUrl in chapterUrls) {
                        val chKey = sha256(chapterUrl).take(16)
                        val chDir = File(mangaDir, chKey)
                        try {
                            if (chDir.exists()) {
                                chDir.deleteRecursively()
                            }
                            // Missing dir still counts as deleted (already gone).
                            deleted.add(chapterUrl)
                        } catch (e: Exception) {
                            Log.e(TAG, "deleteChapters: failed $chapterUrl", e)
                        }
                    }
                    // Prune empty manga directory (Mihon empty-manga prune).
                    try {
                        val leftover = mangaDir.listFiles()
                        if (mangaDir.isDirectory && (leftover == null || leftover.isEmpty())) {
                            mangaDir.delete()
                        }
                    } catch (e: Exception) {
                        Log.w(TAG, "deleteChapters: prune manga dir failed", e)
                    }
                    json.encodeToString(buildJsonObject {
                        put("deleted", JsonArray(deleted.map { JsonPrimitive(it) }))
                    })
                }
                "getExtensionMetadata" -> {
                    withLoadedExtension(root.str("sourceId"), data) { src ->
                        json.encodeToString(buildJsonObject {
                            put("id", src.id.toString())
                            put("name", src.name)
                            put("lang", src.lang)
                            put("baseUrl", src.baseUrl)
                        })
                    }
                }
                "headersManga", "headersAnime" -> json.encodeToString(buildJsonObject { })
                "supportLatestManga", "supportLatestAnime" -> json.encodeToString(JsonPrimitive(true))
                "filtersManga", "filtersAnime" -> {
                    withLoadedExtension(root.str("sourceId"), data) { src ->
                        val fl = try {
                            src.getFilterList()
                        } catch (_: AbstractMethodError) {
                            FilterList()
                        }
                        json.encodeToString(JsonArray(fl.map { filterToJson(it) }))
                    }
                }
                "preferencesManga", "preferencesAnime" -> json.encodeToString(JsonArray(emptyList()))
                else -> errorJson("unknown method: $method")
            }
            result
        } catch (e: Throwable) {
            Log.e(TAG, "handleRequest: error", e)
            errorJson("error: ${e.message}")
        }
    }

    // -- Helpers -----------------------------------------------------------

    /**
     * Download a single page with Mihon Downloader–style retries (3 attempts,
     * 2s / 4s backoff). Returns true when a non-empty file was written.
     */
    private fun downloadPageWithRetry(
        src: HttpSource,
        page: Page,
        file: File,
        chapterName: String,
    ): Boolean {
        var lastError: Exception? = null
        for (attempt in 0 until 3) {
            try {
                if (page.imageUrl.isNullOrEmpty()) {
                    page.imageUrl = runBlocking { src.getImageUrl(page) }
                }
                if (page.imageUrl.isNullOrEmpty()) {
                    throw IOException("empty imageUrl for page ${page.index}")
                }
                val response = runBlocking { src.getImage(page) }
                try {
                    if (!response.isSuccessful) {
                        throw IOException("HTTP ${response.code} for page ${page.index}")
                    }
                    val bytes = response.body.bytes()
                    if (bytes == null || bytes.isEmpty()) {
                        throw IOException("empty body for page ${page.index}")
                    }
                    file.parentFile?.mkdirs()
                    // Write via temp then rename so a crashed attempt does not
                    // leave a truncated JPEG counted as "exists".
                    val tmp = File(file.parentFile, "${file.name}.tmp")
                    tmp.writeBytes(bytes)
                    if (file.exists()) file.delete()
                    if (!tmp.renameTo(file)) {
                        tmp.copyTo(file, overwrite = true)
                        tmp.delete()
                    }
                    return file.exists() && file.length() > 0L
                } finally {
                    response.close()
                }
            } catch (e: Exception) {
                lastError = e
                Log.w(
                    TAG,
                    "download: page ${page.index} of $chapterName " +
                        "attempt ${attempt + 1}/3 failed: ${e.message}",
                )
                if (attempt < 2) {
                    try {
                        Thread.sleep((2L shl attempt) * 1000L)
                    } catch (_: InterruptedException) {
                    }
                }
            }
        }
        Log.e(TAG, "download: giving up page ${page.index} of $chapterName", lastError)
        return false
    }

    /**
     * Build an [SManga] with the same fields Mihon puts in `Manga.toSManga()`
     * before calling `getMangaUpdate`. Extensions such as AllAnime read
     * memo/title during details fetch and NPE when they stay at defaults.
     */
    private fun hydrateSManga(root: JsonObject): SManga {
        val url = root.str("url") ?: ""
        return SManga.create().apply {
            this.url = url
            title = root.str("title") ?: ""
            artist = root.str("artist")
            author = root.str("author")
            description = root.str("description")
            genre = root.str("genre")
            status = root.int("status") ?: 0
            thumbnail_url = root.str("thumbnail_url")
            memo = root.memo()
        }
    }

    private fun JsonObject.str(key: String): String? = (this[key] as? JsonPrimitive)?.content

    private fun JsonObject.int(key: String): Int? = str(key)?.toIntOrNull()

    /// Reads the optional `memo` field, accepting either a nested JsonObject
    /// or a JSON-encoded string (as marshalled by BridgeMappings.toMap()).
    private fun JsonObject.memo(key: String = "memo"): JsonObject = when (val v = this[key]) {
        is JsonObject -> v
        is JsonPrimitive -> runCatching { json.parseToJsonElement(v.content).jsonObject }
            .getOrDefault(JsonObject.EMPTY)

        else -> JsonObject.EMPTY
    }

    private fun errorJson(message: String): String = json.encodeToString(buildJsonObject {
        put("error", message)
        put("code", 500)
    })

    private fun sendResponse(output: OutputStream, statusCode: Int, body: String) {
        val bodyBytes = body.toByteArray(StandardCharsets.UTF_8)
        val response = "HTTP/1.1 $statusCode OK\r\n" +
            "Content-Type: application/json\r\n" +
            "Content-Length: ${bodyBytes.size}\r\n" +
            "Connection: close\r\n" +
            "\r\n"
        output.write(response.toByteArray(StandardCharsets.UTF_8))
        output.write(bodyBytes)
        output.flush()
    }

    /** Open an HTTP response that streams one JSON object per line. */
    private fun beginNdjsonResponse(output: OutputStream) {
        val header = "HTTP/1.1 200 OK\r\n" +
            "Content-Type: application/x-ndjson\r\n" +
            "Connection: close\r\n" +
            "\r\n"
        output.write(header.toByteArray(StandardCharsets.UTF_8))
        output.flush()
    }

    private fun writeNdjsonLine(output: OutputStream, obj: JsonObject) {
        val line = json.encodeToString(obj as JsonElement) + "\n"
        output.write(line.toByteArray(StandardCharsets.UTF_8))
        output.flush()
    }

    /**
     * Streams download progress as NDJSON:
     * - `{"type":"progress","chapterUrl":"...","done":n,"total":m}`
     * - `{"type":"result","chapters":{ url: [paths...] }}`
     * - `{"type":"error","message":"..."}` on fatal setup failure
     */
    private fun streamDownloadChapters(output: OutputStream, root: JsonObject) {
        beginNdjsonResponse(output)
        try {
            val mangaUrl = root.str("mangaUrl")
            if (mangaUrl == null) {
                writeNdjsonLine(output, buildJsonObject {
                    put("type", "error")
                    put("message", "missing mangaUrl")
                })
                return
            }
            val chapterUrls = (root["chapterUrls"] as? JsonArray)
                ?.map { (it as? JsonPrimitive)?.content ?: "" }
                ?: emptyList()
            val chapterNames = (root["chapterNames"] as? JsonArray)
                ?.map { (it as? JsonPrimitive)?.content ?: "" }
                ?: emptyList()
            val chapterMemos = (root["chapterMemos"] as? JsonArray)
                ?.map { (it as? JsonPrimitive)?.content ?: "" }
                ?: emptyList()
            val sourceId = root.str("sourceId") ?: ""
            val data = (root["data"] as? JsonPrimitive)?.content

            withLoadedExtension(root.str("sourceId"), data) { src ->
                val mangaKey = sha256(mangaUrl).take(16)
                val baseDir = File(context.filesDir, "manga/$sourceId/$mangaKey")
                baseDir.mkdirs()
                val result = mutableMapOf<String, List<String>>()
                for ((i, chapterUrl) in chapterUrls.withIndex()) {
                    if (chapterUrl.isBlank()) continue
                    val chName = chapterNames.getOrElse(i) { chapterUrl }
                    val chKey = sha256(chapterUrl).take(16)
                    val chDir = File(baseDir, chKey)
                    chDir.mkdirs()
                    fun emitProgress(done: Int, total: Int) {
                        writeNdjsonLine(output, buildJsonObject {
                            put("type", "progress")
                            put("chapterUrl", chapterUrl)
                            put("done", done)
                            put("total", total)
                        })
                    }
                    try {
                        val chapter = SChapter.create().apply {
                            url = chapterUrl
                            name = chName
                            memo = chapterMemos.getOrElse(i) { "" }.let {
                                if (it.isBlank()) JsonObject.EMPTY
                                else runCatching { json.parseToJsonElement(it).jsonObject }
                                    .getOrDefault(JsonObject.EMPTY)
                            }
                        }
                        // Always re-fetch page list so we know the expected
                        // count — never treat a non-empty directory as done.
                        val pages: List<Page> = runBlocking { src.getPageList(chapter) }
                        if (pages.isEmpty()) {
                            Log.w(TAG, "download: empty page list for $chName")
                            continue
                        }
                        emitProgress(0, pages.size)
                        val localPaths = mutableListOf<String>()
                        var allOk = true
                        for ((pageIdx, page) in pages.withIndex()) {
                            val file = File(chDir, "${page.index}.jpg")
                            if (file.exists() && file.length() > 0L) {
                                localPaths.add(file.absolutePath)
                            } else {
                                val saved = downloadPageWithRetry(src, page, file, chName)
                                if (saved) {
                                    localPaths.add(file.absolutePath)
                                } else {
                                    allOk = false
                                }
                            }
                            emitProgress(pageIdx + 1, pages.size)
                        }
                        // Mihon Downloader parity: only report success when
                        // every page file exists.
                        if (allOk && localPaths.size == pages.size) {
                            result[chapterUrl] = localPaths
                        } else {
                            Log.w(
                                TAG,
                                "download: incomplete $chName " +
                                    "${localPaths.size}/${pages.size} pages",
                            )
                        }
                    } catch (e: Exception) {
                        // One chapter (or CF challenge) failing must not
                        // abort the rest of the batch.
                        Log.e(TAG, "download: chapter failed $chName", e)
                    }
                }
                writeNdjsonLine(output, buildJsonObject {
                    put("type", "result")
                    put("chapters", result.toJsonElement())
                })
            }
        } catch (e: Exception) {
            Log.e(TAG, "streamDownloadChapters: fatal", e)
            try {
                writeNdjsonLine(output, buildJsonObject {
                    put("type", "error")
                    put("message", e.message ?: "Download failed")
                })
            } catch (_: Exception) {
            }
        }
    }

    private fun sha256(input: String): String =
        MessageDigest.getInstance("SHA-256")
            .digest(input.toByteArray())
            .joinToString("") { "%02x".format(it) }

    private fun Any?.toJsonElement(): JsonElement = when (this) {
        null -> JsonNull
        is String -> JsonPrimitive(this)
        is Number -> JsonPrimitive(this)
        is Boolean -> JsonPrimitive(this)
        is Map<*, *> -> @Suppress("UNCHECKED_CAST") (this as Map<String, Any?>).toJsonObject()
        is List<*> -> JsonArray(this.map { it.toJsonElement() })
        else -> JsonPrimitive(this.toString())
    }

        private fun Map<String, Any?>.toJsonObject(): JsonObject = JsonObject(
        this.mapValues { it.value.toJsonElement() }
    )

    // -- Filter serialization / deserialization --------------------------------

    private fun filterToJson(filter: Filter<*>): JsonObject = buildJsonObject {
        put("name", filter.name)
        when (filter) {
            is Filter.Header -> put("type", "header")
            is Filter.Separator -> put("type", "separator")
            is Filter.Text -> {
                put("type", "text")
                put("value", filter.state as String)
            }
            is Filter.CheckBox -> {
                put("type", "check")
                put("value", filter.state as Boolean)
            }
            is Filter.TriState -> {
                put("type", "triState")
                put("value", filter.state as Int)
            }
            is Filter.Select<*> -> {
                put("type", "select")
                put("value", filter.state as Int)
                put("options", JsonArray(filter.values.map { JsonPrimitive(it.toString()) }))
            }
            is Filter.Sort -> {
                put("type", "sort")
                put("options", JsonArray(filter.values.map { JsonPrimitive(it) }))
                val sel = filter.state
                if (sel != null) {
                    put("value", JsonObject(mapOf(
                        "index" to JsonPrimitive(sel.index),
                        "ascending" to JsonPrimitive(sel.ascending),
                    )))
                } else {
                    put("value", JsonNull)
                }
            }
            is Filter.Group<*> -> {
                put("type", "group")
                @Suppress("UNCHECKED_CAST")
                val subs = filter.state as? List<Filter<*>> ?: emptyList()
                put("value", JsonArray(subs.map { filterToJson(it) }))
            }
            else -> put("type", "text")
        }
    }

    private fun parseFilters(root: JsonObject): FilterList {
        val arr = root["filters"] as? JsonArray ?: return FilterList()
        val filters = arr.mapNotNull { elem -> parseFilter(elem as? JsonObject) }
        return FilterList(filters)
    }

    /**
     * Apply client-sent filter state onto the source's own [FilterList] so
     * custom filter subclasses remain intact for searchMangaRequest casting.
     * Falls back to rebuilding anonymous filters when lists cannot be aligned.
     */
    private fun applyFilterState(base: FilterList, root: JsonObject): FilterList {
        val arr = root["filters"] as? JsonArray ?: return base
        if (arr.isEmpty()) return base
        val byName = arr.mapNotNull { it as? JsonObject }
            .associateBy { (it["name"] as? JsonPrimitive)?.content ?: "" }
        for (filter in base) {
            val jo = byName[filter.name] ?: continue
            applyOneFilterState(filter, jo)
        }
        return base
    }

    @Suppress("UNCHECKED_CAST")
    private fun applyOneFilterState(filter: Filter<*>, jo: JsonObject) {
        val value = jo["value"]
        when (filter) {
            is Filter.Text -> {
                filter.state = jsonPrimitiveString(value) ?: filter.state
            }
            is Filter.CheckBox -> {
                filter.state = jsonPrimitiveBoolean(value) ?: filter.state
            }
            is Filter.TriState -> {
                filter.state = jsonPrimitiveInt(value) ?: filter.state
            }
            is Filter.Select<*> -> {
                filter.state = jsonPrimitiveInt(value) ?: filter.state
            }
            is Filter.Sort -> {
                if (value is JsonObject) {
                    val idx = jsonPrimitiveInt(value["index"]) ?: 0
                    val asc = jsonPrimitiveBoolean(value["ascending"]) ?: true
                    filter.state = Filter.Sort.Selection(idx, asc)
                }
            }
            is Filter.Group<*> -> {
                val subs = filter.state as? List<*> ?: return
                val valueArr = value as? JsonArray ?: return
                val subByName = valueArr.mapNotNull { it as? JsonObject }
                    .associateBy { (it["name"] as? JsonPrimitive)?.content ?: "" }
                for (sub in subs) {
                    if (sub !is Filter<*>) continue
                    val subJo = subByName[sub.name] ?: continue
                    applyOneFilterState(sub, subJo)
                }
            }
            else -> { /* Header / Separator — no state */ }
        }
    }

    private fun jsonPrimitiveString(el: JsonElement?): String? =
        (el as? JsonPrimitive)?.content

    private fun jsonPrimitiveBoolean(el: JsonElement?): Boolean? =
        (el as? JsonPrimitive)?.content?.toBooleanStrictOrNull()

    private fun jsonPrimitiveInt(el: JsonElement?): Int? =
        (el as? JsonPrimitive)?.content?.toIntOrNull()

    private fun parseFilter(jo: JsonObject?): Filter<*>? {
        if (jo == null) return null
        val name = (jo["name"] as? JsonPrimitive)?.content ?: ""
        val type = (jo["type"] as? JsonPrimitive)?.content ?: "text"
        val value = jo["value"]
        return when (type) {
            "header" -> Filter.Header(name)
            "separator" -> Filter.Separator(name)
            "text" -> object : Filter.Text(name, jsonPrimitiveString(value) ?: "") {}
            "check" -> object : Filter.CheckBox(name, jsonPrimitiveBoolean(value) ?: false) {}
            "triState" -> object : Filter.TriState(name, jsonPrimitiveInt(value) ?: 0) {}
            "select" -> {
                val opts = (jo["options"] as? JsonArray)?.mapNotNull { (it as? JsonPrimitive)?.content } ?: emptyList()
                object : Filter.Select<String>(name, opts.toTypedArray(), jsonPrimitiveInt(value) ?: 0) {}
            }
            "sort" -> {
                val opts = (jo["options"] as? JsonArray)?.mapNotNull { (it as? JsonPrimitive)?.content } ?: emptyList()
                val sel = if (value is JsonObject) {
                    val idx = jsonPrimitiveInt(value["index"]) ?: 0
                    val asc = jsonPrimitiveBoolean(value["ascending"]) ?: true
                    Filter.Sort.Selection(idx, asc)
                } else null
                object : Filter.Sort(name, opts.toTypedArray(), sel) {}
            }
            "group" -> {
                val subFilters = (value as? JsonArray)
                    ?.mapNotNull { parseFilter(it as? JsonObject) } ?: emptyList()
                object : Filter.Group<Filter<*>>(name, subFilters) {}
            }
            else -> null
        }
    }
}
