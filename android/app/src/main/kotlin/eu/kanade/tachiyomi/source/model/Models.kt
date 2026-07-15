package eu.kanade.tachiyomi.source.model

/**
 * Lightweight metadata carriers shared with the Dart side over the
 * MethodChannel. Keep the field set in sync with the JSON shapes
 * emitted by `keiyoushi_service.dart` and stored by the database.
 */

// -- Manga --------------------------------------------------------------

interface SManga {
    var url: String
    var title: String
    var artist: String?
    var author: String?
    var description: String?
    var genre: String?
    var status: Int
    var thumbnail_url: String?
    var initialized: Boolean

    companion object {
        fun create(): SManga = SMangaImpl()
    }
}

class SMangaImpl : SManga {
    override var url: String = ""
    override var title: String = ""
    override var artist: String? = null
    override var author: String? = null
    override var description: String? = null
    override var genre: String? = null
    override var status: Int = 0
    override var thumbnail_url: String? = null
    override var initialized: Boolean = false
}

// -- Chapter ------------------------------------------------------------

interface SChapter {
    var url: String
    var name: String
    var chapter_number: Float
    var scanlator: String?
    var date_upload: Long

    companion object {
        fun create(): SChapter = SChapterImpl()
    }
}

class SChapterImpl : SChapter {
    override var url: String = ""
    override var name: String = ""
    override var chapter_number: Float = 0f
    override var scanlator: String? = null
    override var date_upload: Long = 0L
}

// -- Page ---------------------------------------------------------------

class Page(
    val index: Int,
    var url: String = "",
    var imageUrl: String? = null,
    var uri: String? = null,
)

// -- JSON projections (extension fns work for any impl, not just ours) --

fun SManga.toMap(): Map<String, Any?> = mapOf(
    "url" to url,
    "title" to title,
    "artist" to artist,
    "author" to author,
    "description" to description,
    "genre" to genre,
    "status" to status,
    "thumbnail_url" to thumbnail_url,
    "initialized" to initialized,
)

fun SChapter.toMap(): Map<String, Any?> = mapOf(
    "url" to url,
    "name" to name,
    "chapter_number" to chapter_number.toDouble(),
    "scanlator" to scanlator,
    "date_upload" to date_upload,
)

fun Page.toMap(): Map<String, Any?> = mapOf(
    "index" to index,
    "url" to url,
    "imageUrl" to imageUrl,
    "uri" to uri,
)

// -- Page set -----------------------------------------------------------

data class MangasPage(
    val mangas: List<SManga>,
    val hasNextPage: Boolean,
)

// -- Status enum (matches Tachiyomi's int convention) ------------------

object MangaStatus {
    const val UNKNOWN = 0
    const val ONGOING = 1
    const val COMPLETED = 2
    const val LICENSED = 3
    const val PUBLISHING_FINISHED = 4
    const val CANCELLED = 5
    const val ON_HIATUS = 6
}
