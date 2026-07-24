package eu.kanade.tachiyomi.network

import eu.kanade.tachiyomi.network.interceptor.UncaughtExceptionInterceptor
import eu.kanade.tachiyomi.network.interceptor.UserAgentInterceptor
import okhttp3.Headers
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody
import okhttp3.RequestBody.Companion.toRequestBody
import java.util.concurrent.TimeUnit

/**
 * Minimal NetworkHelper matching Mihon's extension-facing interface.
 *
 * The UncaughtExceptionInterceptor is required because extensions compiled against
 * extension-lib 1.5+ expect it as the first interceptor in the chain.
 */
open class NetworkHelper(val client: OkHttpClient) {
    open fun defaultUserAgentProvider(): String = "Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36"
}

/**
 * Builds a default OkHttpClient matching Mihon's production setup.
 * Extensions expect UncaughtExceptionInterceptor and UserAgentInterceptor in the chain.
 */
fun defaultClient(): OkHttpClient = OkHttpClient.Builder()
    .cookieJar(AndroidCookieJar())
    .connectTimeout(30, TimeUnit.SECONDS)
    .readTimeout(30, TimeUnit.SECONDS)
    .writeTimeout(30, TimeUnit.SECONDS)
    .callTimeout(2, TimeUnit.MINUTES)
    .addInterceptor(UncaughtExceptionInterceptor())
    .addInterceptor(UserAgentInterceptor { "Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36" })
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
