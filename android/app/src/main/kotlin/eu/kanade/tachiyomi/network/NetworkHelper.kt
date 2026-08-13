package eu.kanade.tachiyomi.network

import android.content.Context
import eu.kanade.tachiyomi.network.interceptor.CloudflareInterceptor
import eu.kanade.tachiyomi.network.interceptor.UncaughtExceptionInterceptor
import eu.kanade.tachiyomi.network.interceptor.UserAgentInterceptor
import eu.kanade.tachiyomi.util.system.WebViewUtil
import okhttp3.Headers
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody
import okhttp3.RequestBody.Companion.toRequestBody
import java.util.concurrent.TimeUnit

/**
 * Mihon-shaped network stack: cookie jar + timeouts + UA/CF interceptors.
 * [defaultUserAgentProvider] must match the WebView UA used to solve CF — cookies
 * like `cf_clearance` are bound to the exact User-Agent string.
 */
class NetworkHelper(private val context: Context) {

    val cookieJar = AndroidCookieJar()

    private val userAgent: String by lazy {
        runCatching { WebViewUtil.getInferredUserAgent(context) }
            .getOrDefault(FALLBACK_USER_AGENT)
            .trim()
            .ifEmpty { FALLBACK_USER_AGENT }
    }

    fun defaultUserAgentProvider(): String = userAgent

    val client: OkHttpClient = OkHttpClient.Builder()
        .cookieJar(cookieJar)
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .writeTimeout(30, TimeUnit.SECONDS)
        .callTimeout(2, TimeUnit.MINUTES)
        .addInterceptor(UncaughtExceptionInterceptor())
        .addInterceptor(UserAgentInterceptor(::defaultUserAgentProvider))
        .addInterceptor(
            CloudflareInterceptor(context, cookieJar, ::defaultUserAgentProvider),
        )
        .build()

    companion object {
        // Mihon NetworkPreferences default (Chrome mobile).
        const val FALLBACK_USER_AGENT =
            "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) " +
                "Chrome/141.0.0.0 Mobile Safari/537.36"
    }
}

/** @deprecated Prefer [NetworkHelper.client]; kept for call sites that only need a client. */
fun defaultClient(context: Context? = null): OkHttpClient {
    if (context != null) return NetworkHelper(context).client
    return OkHttpClient.Builder()
        .cookieJar(AndroidCookieJar())
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .writeTimeout(30, TimeUnit.SECONDS)
        .callTimeout(2, TimeUnit.MINUTES)
        .addInterceptor(UncaughtExceptionInterceptor())
        .addInterceptor(UserAgentInterceptor { NetworkHelper.FALLBACK_USER_AGENT })
        .build()
}

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
