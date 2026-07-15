package eu.kanade.tachiyomi.extension

import android.content.Context
import eu.kanade.tachiyomi.source.Source
import eu.kanade.tachiyomi.source.model.MangasPage
import eu.kanade.tachiyomi.source.model.Page
import eu.kanade.tachiyomi.source.model.SChapter
import eu.kanade.tachiyomi.source.model.SManga
import eu.kanade.tachiyomi.source.online.HttpSource
import java.util.concurrent.ConcurrentHashMap

/**
 * In-memory registry of loaded Keiyoushi extension sources.
 *
 * Responsibilities:
 *  - Own the [ExtensionLoader] (the DexClassLoader pipeline).
 *  - Map `sourceId → Source` so MethodChannel handlers can look up
 *    a loaded source by its stable id and dispatch calls.
 *  - Map `apkPath → sourceId(s)` so we can unload cleanly when the
 *    Dart side removes an extension APK.
 */
class KeiyoushiEngine(
    private val context: Context,
    private val loader: ExtensionLoader = ExtensionLoader(context),
) {

    private val sourceById: MutableMap<String, Source> = ConcurrentHashMap()
    // A single APK can ship multiple Source classes; track all of them.
    private val idsByApkPath: MutableMap<String, MutableSet<String>> = ConcurrentHashMap()

    /** Short description of every loaded source, for the UI. */
    fun listLoaded(): List<Map<String, Any?>> =
        sourceById.values.map { it.toDescriptor() }

    /**
     * Load a [Source] from an APK on disk and register it.
     *
     * Returns the source descriptor so the Dart side can persist it
     * (id, name, lang, apkPath, className) in the database.
     */
    fun loadExtension(apkPath: String, className: String): Map<String, Any?> {
        val source = loader.loadFromApk(apkPath, className)
        val id = source.id.toString()
        sourceById[id] = source
        idsByApkPath.getOrPut(apkPath) { mutableSetOf() }.add(id)
        return source.toDescriptor(apkPath = apkPath, className = className)
    }

    fun unloadExtension(sourceId: String) {
        val source = sourceById.remove(sourceId) ?: return
        // Find which APK owned this source and remove it from the index.
        val apkPath = idsByApkPath.entries.firstOrNull { it.value.contains(sourceId) }?.key
        if (apkPath != null) {
            idsByApkPath[apkPath]?.remove(sourceId)
            // If no sources remain from this APK, unload the classloader.
            if (idsByApkPath[apkPath]?.isEmpty() == true) {
                idsByApkPath.remove(apkPath)
                loader.unloadApk(apkPath)
            }
        }
        // The Source is now unreferenced; the classloader drop will GC
        // its classes on the next pass.
        source.toString()
    }

    // -- Source operations (call into loaded HttpSource) ------------------

    fun getPopularManga(sourceId: String, page: Int): MangasPage =
        requireHttpSource(sourceId).getPopularManga(page)

    fun searchManga(sourceId: String, query: String, page: Int): MangasPage =
        requireHttpSource(sourceId).searchManga(page, query)

    fun getMangaDetails(sourceId: String, url: String): SManga {
        val src = requireHttpSource(sourceId)
        val sm = src.getMangaDetails(url)
        // Some extensions forget to mark the SManga as initialized; the
        // Dart side relies on this flag to skip persisting partial data.
        if (!sm.initialized) sm.initialized = true
        return sm
    }

    fun getChapterList(sourceId: String, url: String): List<SChapter> =
        requireHttpSource(sourceId).getChapterList(url)

    fun getPageList(sourceId: String, url: String): List<Page> =
        requireHttpSource(sourceId).getPageList(url)

    // -- Internals --------------------------------------------------------

    private fun requireSource(sourceId: String): Source =
        sourceById[sourceId]
            ?: throw IllegalStateException("Source not loaded: $sourceId")

    private fun requireHttpSource(sourceId: String): HttpSource {
        val src = requireSource(sourceId)
        if (src !is HttpSource) {
            throw IllegalStateException(
                "Source $sourceId is not an HttpSource (got ${src.javaClass.name})"
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
