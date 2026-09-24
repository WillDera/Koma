package eu.kanade.tachiyomi.extension

/**
 * Derive catalogue `mangaId` values from manga/chapter URLs for sources that
 * expect them in chapter memo during getPageList.
 *
 * Shared by [DalvikServer] and host page-list helpers so hydration is not
 * tied to a single extension.
 */
object ChapterMemoIds {
    private val patterns = listOf(
        Regex("""/manga/([^/?#]+)"""),
        Regex("""/title/([^/?#]+)"""),
        Regex("""/series/([^/?#]+)"""),
        Regex("""/comic/([^/?#]+)"""),
    )

    fun extract(url: String?): String? {
        if (url.isNullOrBlank()) return null
        val t = url.trim()
        if (!t.contains('/')) return t.takeIf { it.isNotEmpty() }
        for (p in patterns) {
            val m = p.find(t) ?: continue
            val id = m.groupValues.getOrNull(1)?.trim()
            if (!id.isNullOrEmpty()) return id
        }
        return null
    }
}
