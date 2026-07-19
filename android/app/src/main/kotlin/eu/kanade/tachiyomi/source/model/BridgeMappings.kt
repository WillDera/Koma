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
