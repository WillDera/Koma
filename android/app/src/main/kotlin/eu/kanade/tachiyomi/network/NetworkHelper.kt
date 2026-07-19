package eu.kanade.tachiyomi.network

import okhttp3.Headers
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody
import okhttp3.RequestBody.Companion.toRequestBody
import java.util.concurrent.TimeUnit

open class NetworkHelper(val client: OkHttpClient) {
    open fun defaultUserAgentProvider(): String = "Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36"
}

fun defaultClient(): OkHttpClient = OkHttpClient.Builder()
    .connectTimeout(20, TimeUnit.SECONDS)
    .readTimeout(30, TimeUnit.SECONDS)
    .writeTimeout(20, TimeUnit.SECONDS)
    .build()

fun GET(url: String, headers: Headers? = null, cache: Boolean = true): Request {
    val builder = Request.Builder().url(url)
    if (headers != null) builder.headers(headers)
    return builder.get().build()
}

fun POST(
    url: String,
    headers: Headers? = null,
    body: RequestBody = "".toRequestBody(),
    cache: Boolean = true,
): Request {
    val builder = Request.Builder().url(url)
    if (headers != null) builder.headers(headers)
    return builder.post(body).build()
}

fun HEAD(url: String, headers: Headers? = null): Request {
    val builder = Request.Builder().url(url)
    if (headers != null) builder.headers(headers)
    return builder.head().build()
}

/** Convenience for form-encoded POSTs. */
fun formBody(vararg pairs: Pair<String, String>): RequestBody =
    pairs.joinToString("&") { (k, v) ->
        "${java.net.URLEncoder.encode(k, "UTF-8")}=${java.net.URLEncoder.encode(v, "UTF-8")}"
    }.toRequestBody("application/x-www-form-urlencoded".toMediaType())

/** Convenience for JSON POSTs. */
fun jsonBody(json: String): RequestBody =
    json.toRequestBody("application/json; charset=utf-8".toMediaType())
