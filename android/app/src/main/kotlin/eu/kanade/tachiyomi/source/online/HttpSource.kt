package eu.kanade.tachiyomi.source.online

import eu.kanade.tachiyomi.source.Source
import eu.kanade.tachiyomi.source.model.MangasPage
import eu.kanade.tachiyomi.source.model.Page
import eu.kanade.tachiyomi.source.model.SChapter
import eu.kanade.tachiyomi.source.model.SManga
import okhttp3.Headers
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import java.util.concurrent.TimeUnit

/**
 * Abstract base for network-based Keiyoushi extensions.
 *
 * The contract is intentionally identical to the upstream Tachiyomi
 * `HttpSource`: the extension author provides `*Request` builders and
 * `*Parse` functions, and the convenience methods here stitch them
 * together. This means a real Keiyoushi `.apk` extension compiled
 * against the upstream source-api will link against this class without
 * any modification.
 */
abstract class HttpSource : Source {

    /** Root URL of the site (no trailing slash). */
    abstract val baseUrl: String

    /** Lazy-initialized OkHttp client. Reusing a single client per source
     *  is important — it keeps the connection pool and cookie jar warm. */
    open val client: OkHttpClient by lazy {
        OkHttpClient.Builder()
            .connectTimeout(20, TimeUnit.SECONDS)
            .readTimeout(30, TimeUnit.SECONDS)
            .writeTimeout(20, TimeUnit.SECONDS)
            .build()
    }

    /** Default headers sent with every request. Extensions may extend
     *  these in their own `headers` override. */
    open val headers: Headers by lazy {
        Headers.Builder()
            .add("User-Agent", "Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36")
            .add("Referer", baseUrl)
            .build()
    }

    // -- Request / parse pairs the extension must implement ----------------

    abstract fun popularMangaRequest(page: Int): Request
    abstract fun popularMangaParse(response: Response): MangasPage

    abstract fun searchMangaRequest(page: Int, query: String, filters: FilterList): Request
    abstract fun searchMangaParse(response: Response): MangasPage

    abstract fun latestUpdatesRequest(page: Int): Request
    abstract fun latestUpdatesParse(response: Response): MangasPage

    abstract fun mangaDetailsParse(response: Response): SManga
    abstract fun chapterListParse(response: Response): List<SChapter>
    abstract fun pageListParse(response: Response): List<Page>

    // -- Convenience wrappers ---------------------------------------------

    open fun getPopularManga(page: Int): MangasPage =
        client.newCall(popularMangaRequest(page)).execute().use(::popularMangaParse)

    open fun searchManga(page: Int, query: String, filters: FilterList = FilterList()): MangasPage =
        client.newCall(searchMangaRequest(page, query, filters)).execute().use(::searchMangaParse)

    open fun getLatestUpdates(page: Int): MangasPage =
        client.newCall(latestUpdatesRequest(page)).execute().use(::latestUpdatesParse)

    open fun getMangaDetails(url: String): SManga {
        val req = Request.Builder().url(url).headers(headers).build()
        return client.newCall(req).execute().use(::mangaDetailsParse)
    }

    open fun getChapterList(url: String): List<SChapter> {
        val req = Request.Builder().url(url).headers(headers).build()
        return client.newCall(req).execute().use(::chapterListParse)
    }

    open fun getPageList(url: String): List<Page> {
        val req = Request.Builder().url(url).headers(headers).build()
        return client.newCall(req).execute().use(::pageListParse)
    }

    // -- Filter plumbing (minimal — extensions define their own filters) --

    open fun getFilterList(): FilterList = FilterList()
}

/**
 * Bare-bones FilterList that extensions can populate. The real
 * `tachiyomi.source.model.Filter` package has dozens of concrete
 * filter types; we expose the type alias so extension bytecode that
 * references `FilterList` still resolves.
 */
typealias Filter = Any
class FilterList : MutableList<Filter> by ArrayList()
