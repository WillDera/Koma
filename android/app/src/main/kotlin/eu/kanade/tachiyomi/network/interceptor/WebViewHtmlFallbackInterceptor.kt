package eu.kanade.tachiyomi.network.interceptor

import android.util.Log
import android.webkit.CookieManager
import keiyoushi.utils.WebViewTimeoutException
import keiyoushi.utils.runWebViewBlocking
import okhttp3.Interceptor
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.Protocol
import okhttp3.Response
import okhttp3.ResponseBody.Companion.toResponseBody
import org.json.JSONObject
import java.io.IOException
import kotlin.time.Duration.Companion.milliseconds
import kotlin.time.Duration.Companion.seconds

/**
 * When OkHttp gets a bare 403/503 (often Cloudflare bot-score / TLS fingerprint
 * blocks that never set [cf-mitigated]), fetch the same GET URL through Chromium
 * WebView and return the HTML as a synthetic 200.
 *
 * Opening the in-app browser alone often does not help: WebView may load the
 * page without ever minting a `cf_clearance` cookie that OkHttp can reuse, or
 * clearance is bound to a browser TLS fingerprint OkHttp cannot mimic.
 *
 * Must sit **outside** [CloudflareInterceptor] so `cf-mitigated` challenges are
 * still solved the Mihon way first; this only handles leftover bare 403/503.
 */
class WebViewHtmlFallbackInterceptor(
    private val defaultUserAgentProvider: () -> String,
) : Interceptor {

    override fun intercept(chain: Interceptor.Chain): Response {
        val request = chain.request()
        val response = chain.proceed(request)

        if (request.method != "GET") return response
        if (response.code !in ERROR_CODES) return response

        val accept = request.header("Accept").orEmpty()
        if (accept.contains("image/") && !accept.contains("text/html")) {
            return response
        }

        val url = request.url.toString()
        val server = response.header("Server")
        val cfMitigated = response.header("cf-mitigated")
        val hasClearance = CookieManager.getInstance()
            .getCookie(url)
            ?.contains("cf_clearance=") == true

        Log.w(
            TAG,
            "HTTP ${response.code} for $url server=$server " +
                "cf-mitigated=$cfMitigated cf_clearance=$hasClearance — WebView HTML fallback",
        )
        response.close()

        val ua = request.header("User-Agent") ?: defaultUserAgentProvider()
        val headerMap = request.headers
            .filter { (name, _) ->
                val n = name.lowercase()
                n !in SKIP_REQUEST_HEADERS && !n.startsWith("proxy-")
            }
            .groupBy({ it.first }, { it.second })
            .mapValues { it.value.first() }

        val html: String = try {
            runWebViewBlocking<String>(chain.call(), timeout = 45.seconds) {
                userAgent = ua
                blockImages = true

                onPageFinished {
                    poll(interval = 750.milliseconds) {
                        evaluateJs(CHALLENGE_DETECT_JS) { challenged ->
                            if (challenged == "true" || challenged == "\"true\"") {
                                // Keep polling — auto challenges may clear; Turnstile needs the user.
                                return@evaluateJs
                            }
                            evaluateJs("document.documentElement.outerHTML") { raw ->
                                val page = decodeJsString(raw)
                                if (page != null &&
                                    page.length > 400 &&
                                    !looksLikeChallengeHtml(page)
                                ) {
                                    CookieManager.getInstance().flush()
                                    resolve(page)
                                }
                            }
                        }
                    }
                }

                loadUrl(url, headerMap)
            }
        } catch (e: WebViewTimeoutException) {
            throw IOException(
                "Timed out loading $url in WebView (Cloudflare?). " +
                    "Open the source website, solve the captcha, then retry.",
                e,
            )
        } catch (e: IOException) {
            throw e
        } catch (e: Exception) {
            throw IOException("WebView fallback failed for $url: ${e.message}", e)
        }

        return Response.Builder()
            .request(request)
            .protocol(Protocol.HTTP_1_1)
            .code(200)
            .message("OK")
            .body(html.toByteArray(Charsets.UTF_8).toResponseBody(HTML_UTF8))
            .build()
    }

    companion object {
        private const val TAG = "WebViewHtmlFallback"
        private val ERROR_CODES = listOf(403, 503)
        private val HTML_UTF8 = "text/html; charset=utf-8".toMediaType()
        private val SKIP_REQUEST_HEADERS = setOf(
            "content-length", "host", "trailer", "te", "upgrade", "cookie2",
            "keep-alive", "transfer-encoding", "set-cookie", "accept-encoding",
        )

        private val CHALLENGE_DETECT_JS = """
            (function () {
              return !!(
                document.querySelector(
                  '#challenge-form, #challenge-error-title, #challenge-error-text, ' +
                  'iframe[src*="challenges.cloudflare"], iframe[src*="turnstile"]'
                ) ||
                document.title.toLowerCase().includes('just a moment')
              );
            })()
        """.trimIndent()

        private fun looksLikeChallengeHtml(html: String): Boolean {
            val lower = html.lowercase()
            return "challenge-platform" in lower ||
                "cf-browser-verification" in lower ||
                "cdn-cgi/challenge" in lower ||
                ("just a moment" in lower && "cloudflare" in lower)
        }

        private fun decodeJsString(raw: String?): String? {
            if (raw == null || raw == "null") return null
            return try {
                if (raw.length >= 2 && raw.first() == '"' && raw.last() == '"') {
                    JSONObject("{\"v\":$raw}").getString("v")
                } else {
                    raw
                }
            } catch (_: Exception) {
                raw
            }
        }
    }
}
