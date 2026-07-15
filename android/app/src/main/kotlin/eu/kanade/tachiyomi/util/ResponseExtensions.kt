package eu.kanade.tachiyomi.util

import okhttp3.Response
import org.jsoup.Jsoup
import org.jsoup.nodes.Document

/**
 * Extension functions on `okhttp3.Response` so the Java code can chain
 * like `response.asJsoup().select(...)`.
 */

fun Response.asJsoup(): Document = use { Jsoup.parse(body!!.string(), request.url.toString()) }

fun Response.asJsoup(charset: String): Document =
    use { Jsoup.parse(body!!.byteStream(), charset, request.url.toString()) }

fun Response.bodyAsString(): String = use { body!!.string() }
