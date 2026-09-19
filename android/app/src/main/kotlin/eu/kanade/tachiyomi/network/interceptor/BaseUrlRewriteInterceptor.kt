package eu.kanade.tachiyomi.network.interceptor

import android.util.Log
import okhttp3.HttpUrl
import okhttp3.HttpUrl.Companion.toHttpUrlOrNull
import okhttp3.Interceptor
import okhttp3.Response
import java.util.concurrent.ConcurrentHashMap

/**
 * Rewrites request hosts from a Mihon extension's packaged domain to the
 * user's Source URL override.
 *
 * Mutating [eu.kanade.tachiyomi.source.online.HttpSource.baseUrl] alone is not
 * enough — many APKs hardcode the old host in `popularMangaRequest` /
 * companion constants. Any client derived from [eu.kanade.tachiyomi.network.NetworkHelper.client]
 * (via `newBuilder()`) inherits this interceptor.
 */
object BaseUrlHostRewrite {
    private const val TAG = "BaseUrlHostRewrite"

    /** oldHost (lowercase) → replacement origin (scheme/host/port). */
    private val byOldHost = ConcurrentHashMap<String, HttpUrl>()

    fun register(packagedBaseUrl: String, overrideBaseUrl: String) {
        val from = packagedBaseUrl.trim().trimEnd('/').toHttpUrlOrNull() ?: return
        val to = overrideBaseUrl.trim().trimEnd('/').toHttpUrlOrNull() ?: return
        if (from.host.equals(to.host, ignoreCase = true) &&
            from.scheme.equals(to.scheme, ignoreCase = true) &&
            from.port == to.port
        ) {
            byOldHost.remove(from.host.lowercase())
            return
        }
        byOldHost[from.host.lowercase()] = to
        Log.d(TAG, "rewrite ${from.host} → ${to.scheme}://${to.host}:${to.port}")
    }

    fun unregisterPackaged(packagedBaseUrl: String) {
        val from = packagedBaseUrl.trim().trimEnd('/').toHttpUrlOrNull() ?: return
        byOldHost.remove(from.host.lowercase())
    }

    fun clearAll() {
        byOldHost.clear()
    }

    fun rewrite(url: HttpUrl): HttpUrl? {
        val to = byOldHost[url.host.lowercase()] ?: return null
        return url.newBuilder()
            .scheme(to.scheme)
            .host(to.host)
            .port(to.port)
            .build()
    }

    /** Rewrite absolute http(s) header values that still point at a packaged host. */
    fun rewriteHeaderValue(value: String): String {
        val trimmed = value.trim()
        val url = trimmed.toHttpUrlOrNull() ?: return value
        val rewritten = rewrite(url) ?: return value
        // Preserve a trailing slash if the original Referer had one.
        val out = rewritten.toString().trimEnd('/')
        return if (trimmed.endsWith('/')) "$out/" else out
    }
}

class BaseUrlRewriteInterceptor : Interceptor {
    override fun intercept(chain: Interceptor.Chain): Response {
        val request = chain.request()
        val rewrittenUrl = BaseUrlHostRewrite.rewrite(request.url)
        val builder = request.newBuilder()

        var changed = false
        if (rewrittenUrl != null && rewrittenUrl != request.url) {
            Log.d(
                "BaseUrlHostRewrite",
                "req ${request.url} → $rewrittenUrl",
            )
            builder.url(rewrittenUrl)
            changed = true
        }

        for (name in listOf("Referer", "Origin")) {
            val raw = request.header(name) ?: continue
            val next = BaseUrlHostRewrite.rewriteHeaderValue(raw)
            if (next != raw) {
                builder.header(name, next)
                changed = true
            }
        }

        return chain.proceed(if (changed) builder.build() else request)
    }
}
