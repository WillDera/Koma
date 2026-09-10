package eu.kanade.tachiyomi.source.model

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
    "memo" to memo.toString(),
)

fun SChapter.toMap(): Map<String, Any?> = mapOf(
    "url" to url,
    "name" to name,
    "chapter_number" to chapter_number.toDouble(),
    "scanlator" to scanlator,
    "date_upload" to date_upload,
    "memo" to memo.toString(),
)

fun Page.toMap(): Map<String, Any?> = mapOf(
    "index" to index,
    // Prefer the resolved bitmap URL. Page.url is often a viewer HTML page
    // (e.g. /g/id/120/); imageUrl is the CDN jpg after getImageUrl.
    "url" to (imageUrl?.takeIf { it.isNotEmpty() } ?: url),
    "imageUrl" to imageUrl,
    "uri" to uri?.toString(),
)
