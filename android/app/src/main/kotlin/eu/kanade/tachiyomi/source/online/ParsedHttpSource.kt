package eu.kanade.tachiyomi.source.online

import eu.kanade.tachiyomi.source.model.MangasPage
import eu.kanade.tachiyomi.source.model.SManga
import eu.kanade.tachiyomi.util.asJsoup
import okhttp3.Response
import org.jsoup.nodes.Document

/**
 * Adds CSS-selector-based parsing helpers on top of [HttpSource].
 *
 * Subclasses declare selector strings (e.g. `popularMangaSelector =
 * "div.manga-item"`) and override `*Selector` properties; the default
 * `*Parse` implementations walk the document with those selectors.
 *
 * This is a slimmer version of the upstream class — enough for a lot
 * of Keiyoushi extensions to load. We can flesh it out (filters,
 * pagination parsing, etc.) as concrete extensions demand it.
 */
abstract class ParsedHttpSource : HttpSource() {

    // -- Selectors (subclasses override) ----------------------------------

    protected open val popularMangaSelector: String = ""
    protected open val popularMangaFromElementSelector: String = ""
    protected open val popularMangaNextPageSelector: String = ""

    protected open val searchMangaSelector: String = ""
    protected open val searchMangaFromElementSelector: String = ""
    protected open val searchMangaNextPageSelector: String = ""

    protected open val latestUpdatesSelector: String = ""
    protected open val latestUpdatesFromElementSelector: String = ""
    protected open val latestUpdatesNextPageSelector: String = ""

    // -- Default parses that subclasses inherit ---------------------------

    override fun popularMangaParse(response: Response): MangasPage {
        val doc = response.asJsoup()
        val mangas = doc.select(popularMangaSelector).map { element ->
            popularMangaFromElement(element)
        }
        val hasNextPage = popularMangaNextPageSelector.isNotEmpty() &&
            doc.select(popularMangaNextPageSelector).any()
        return MangasPage(mangas, hasNextPage)
    }

    override fun searchMangaParse(response: Response): MangasPage {
        val doc = response.asJsoup()
        val mangas = doc.select(searchMangaSelector).map { element ->
            searchMangaFromElement(element)
        }
        val hasNextPage = searchMangaNextPageSelector.isNotEmpty() &&
            doc.select(searchMangaNextPageSelector).any()
        return MangasPage(mangas, hasNextPage)
    }

    override fun latestUpdatesParse(response: Response): MangasPage {
        val doc = response.asJsoup()
        val mangas = doc.select(latestUpdatesSelector).map { element ->
            latestUpdatesFromElement(element)
        }
        val hasNextPage = latestUpdatesNextPageSelector.isNotEmpty() &&
            doc.select(latestUpdatesNextPageSelector).any()
        return MangasPage(mangas, hasNextPage)
    }

    // -- Per-element extractors (subclasses override) ---------------------

    protected open fun popularMangaFromElement(element: org.jsoup.nodes.Element): SManga =
        SManga.create().apply {
            url = element.selectFirst(popularMangaFromElementSelector)?.attr("href") ?: ""
            title = element.text()
        }

    protected open fun searchMangaFromElement(element: org.jsoup.nodes.Element): SManga =
        SManga.create().apply {
            url = element.selectFirst(searchMangaFromElementSelector)?.attr("href") ?: ""
            title = element.text()
        }

    protected open fun latestUpdatesFromElement(element: org.jsoup.nodes.Element): SManga =
        SManga.create().apply {
            url = element.selectFirst(latestUpdatesFromElementSelector)?.attr("href") ?: ""
            title = element.text()
        }
}
