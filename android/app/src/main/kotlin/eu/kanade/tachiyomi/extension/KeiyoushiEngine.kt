package eu.kanade.tachiyomi.extension

import android.app.Application
import android.content.Context
import android.util.Log
import eu.kanade.tachiyomi.network.NetworkHelper
import eu.kanade.tachiyomi.source.CatalogueSource
import eu.kanade.tachiyomi.source.Source
import eu.kanade.tachiyomi.source.model.FilterList
import eu.kanade.tachiyomi.source.model.MangasPage
import eu.kanade.tachiyomi.source.model.Page
import eu.kanade.tachiyomi.source.model.SChapter
import eu.kanade.tachiyomi.source.model.SManga
import eu.kanade.tachiyomi.source.model.SMangaUpdate
import eu.kanade.tachiyomi.source.model.toMap
import eu.kanade.tachiyomi.source.online.HttpSource
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.json.Json
import okhttp3.OkHttpClient
import uy.kohesive.injekt.Injekt
import uy.kohesive.injekt.api.InjektModule
import uy.kohesive.injekt.api.InjektRegistrar
import uy.kohesive.injekt.api.addSingleton
import uy.kohesive.injekt.api.addSingletonFactory
import uy.kohesive.injekt.api.get
import java.util.concurrent.ConcurrentHashMap

class KeiyoushiEngine(
    private val context: Context,
    private val loader: ExtensionLoader = ExtensionLoader(context),
) {
    companion object {
        private const val TAG = "KeiyoushiEngine"
        private var initialized = false
    }

    init {
        if (!initialized) {
            initialized = true
            val app = context.applicationContext as Application
            Injekt.importModule(object : InjektModule {
                override fun InjektRegistrar.registerInjectables() {
                    addSingleton(app)
                    addSingletonFactory {
                        OkHttpClient.Builder()
                            .connectTimeout(30, java.util.concurrent.TimeUnit.SECONDS)
                            .readTimeout(30, java.util.concurrent.TimeUnit.SECONDS)
                            .build()
                    }
                    addSingletonFactory {
                        Json { ignoreUnknownKeys = true; explicitNulls = false; isLenient = true }
                    }
                    addSingletonFactory {
                        NetworkHelper(Injekt.get<OkHttpClient>())
                    }
                }
            })
        }
    }

    private val sourceById: MutableMap<String, Source> = ConcurrentHashMap()
    private val idsByApkPath: MutableMap<String, MutableSet<String>> = ConcurrentHashMap()

    fun listLoaded(): List<Map<String, Any?>> =
        sourceById.values.map { it.toDescriptor() }

    fun loadExtension(apkPath: String, className: String): Map<String, Any?> {
        Log.d(TAG, "loadExtension: apkPath=$apkPath className=$className")
        val source = loader.loadFromApk(apkPath, className)
        val id = source.id.toString()
        sourceById[id] = source
        idsByApkPath.getOrPut(apkPath) { mutableSetOf() }.add(id)
        return source.toDescriptor(apkPath = apkPath, className = className)
    }

    fun unloadExtension(sourceId: String) {
        val source = sourceById.remove(sourceId) ?: return
        val apkPath = idsByApkPath.entries.firstOrNull { it.value.contains(sourceId) }?.key
        if (apkPath != null) {
            idsByApkPath[apkPath]?.remove(sourceId)
            if (idsByApkPath[apkPath]?.isEmpty() == true) {
                idsByApkPath.remove(apkPath)
                loader.unloadApk(apkPath)
            }
        }
        source.toString()
    }

    // -- Source operations via coroutine bridge ---------------------------

    fun getPopularManga(sourceId: String, page: Int): MangasPage =
        runBlocking { requireHttpSource(sourceId).getPopularManga(page) }

    fun getLatestUpdates(sourceId: String, page: Int): MangasPage =
        runBlocking { requireHttpSource(sourceId).getLatestUpdates(page) }

    fun searchManga(sourceId: String, query: String, page: Int): MangasPage =
        runBlocking {
            try {
                requireHttpSource(sourceId).getSearchManga(page, query, FilterList())
            } catch (_: AbstractMethodError) {
                MangasPage(emptyList(), false)
            }
        }

    fun getMangaDetails(sourceId: String, url: String): SManga {
        val src = requireHttpSource(sourceId)
        val manga = SManga.create().apply { this.url = url }
        val result = runBlocking {
            src.getMangaUpdate(manga, emptyList(), fetchDetails = true, fetchChapters = false)
        }
        val details = result.manga
        if (!details.initialized) details.initialized = true
        return details
    }

    fun getChapterList(sourceId: String, url: String): List<SChapter> {
        val src = requireHttpSource(sourceId)
        val manga = SManga.create().apply { this.url = url }
        val result = runBlocking {
            src.getMangaUpdate(manga, emptyList(), fetchDetails = false, fetchChapters = true)
        }
        return result.chapters
    }

    fun getPageList(sourceId: String, url: String): List<Map<String, Any?>> {
        val src = requireHttpSource(sourceId)
        val chapter = SChapter.create().apply { this.url = url }
        return runBlocking {
            src.getPageList(chapter).map { page ->
                val headers = try {
                    src.getImageRequestHeaders(page).toMap()
                } catch (_: Exception) {
                    emptyMap<String, String>()
                }
                page.toMap() + ("headers" to headers)
            }
        }
    }

    /**
     * Search ALL loaded sources for [query]. Returns one entry per source
     * that returned results. Runs searches in parallel.
     */
    fun searchAllInstalled(query: String, page: Int): List<Map<String, Any?>> =
        runBlocking {
            val sources = sourceById.values.filterIsInstance<CatalogueSource>()
            if (sources.isEmpty()) return@runBlocking emptyList()

            coroutineScope {
                val deferred = sources.map { source ->
                    async {
                        try {
                            val mp = source.getSearchManga(page, query, FilterList())
                            source.id.toString() to mp
                        } catch (_: NoClassDefFoundError) {
                            null // extension references a class we don't bundle
                        } catch (_: AbstractMethodError) {
                            null // source doesn't support search
                        } catch (_: Exception) {
                            null
                        }
                    }
                }
                deferred.map { it.await() }
                    .filterNotNull()
                    .map { (id, mp) ->
                        val src = sourceById[id] ?: return@map null
                        mapOf(
                            "sourceId" to id,
                            "sourceName" to src.name,
                            "mangas" to mp.mangas.map(SManga::toMap),
                            "hasNextPage" to mp.hasNextPage,
                        )
                    }
                    .filterNotNull()
            }
        }

    // -- Internals --------------------------------------------------------

    private fun requireSource(sourceId: String): Source =
        sourceById[sourceId] ?: throw IllegalStateException("Source not loaded: $sourceId")

    private fun requireHttpSource(sourceId: String): HttpSource {
        val src = requireSource(sourceId)
        if (src !is HttpSource) {
            throw IllegalStateException(
                "Source $sourceId is not an HttpSource (got ${src.javaClass.name})",
            )
        }
        return src
    }

    private fun Source.toDescriptor(
        apkPath: String? = null,
        className: String? = null,
    ): Map<String, Any?> = mapOf(
        "id" to id.toString(),
        "name" to name,
        "lang" to lang,
        "apkPath" to apkPath,
        "className" to className,
    )
}
