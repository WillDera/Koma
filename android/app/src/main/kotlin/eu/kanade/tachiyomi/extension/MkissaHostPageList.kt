package eu.kanade.tachiyomi.extension

import android.util.Log
import android.webkit.CookieManager
import eu.kanade.tachiyomi.source.model.Page
import eu.kanade.tachiyomi.source.model.SChapter
import eu.kanade.tachiyomi.source.online.HttpSource
import eu.kanade.tachiyomi.util.asJsoup
import keiyoushi.utils.WebViewTimeoutException
import keiyoushi.utils.runWebView
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.Request
import kotlin.time.Duration.Companion.milliseconds
import kotlin.time.Duration.Companion.seconds

/**
 * Host-owned page-list fetch for AllManga / mkissa.
 *
 * Matches the last released implementation (OkHttp manga HTML → head hooks →
 * [loadData] → synthetic chapter click). Do **not** [loadUrl] the chapter page:
 * that re-triggers Cloudflare Turnstile in a headless WebView that cannot be
 * solved, even after the user cleared CF in Open in WebView.
 *
 * The extension APK R8-obfuscates its own `runWebView`, so Dalvik routes here.
 */
object MkissaHostPageList {
    private const val TAG = "MkissaHostPageList"

    /** Mihon numeric id seen in logs for en AllManga (`2e5cd659b0172a4c`). */
    private const val ALLMANGA_EN_ID = 4709139914729853090L

    private val urlRegex = Regex("^https?://.*")
    private val json = Json { ignoreUnknownKeys = true; isLenient = true }

    private val captchaMessage =
        "Solve captcha in WebView and retry"

    fun appliesTo(source: HttpSource): Boolean {
        if (source.id == ALLMANGA_EN_ID) return true
        if (source.baseUrl.contains("mkissa", ignoreCase = true)) return true
        return source.name.contains("AllManga", ignoreCase = true)
    }

    suspend fun fetch(source: HttpSource, chapter: SChapter): List<Page> {
        val mangaId = chapter.memo["mangaId"].asString()
            ?: throw Exception("Refresh Chapter List")
        val base = source.baseUrl.trimEnd('/')
        val mangaUrl = "$base/manga/$mangaId"
        val chapterPath = runCatching {
            source.getChapterUrl(chapter).toHttpUrl().encodedPath
        }.getOrElse {
            "/manga/$mangaId/chapter-${chapter.url}-sub"
        }

        val interfaceName = randomBridgeName()
        val ua = source.headers["User-Agent"]
            ?: source.headers["user-agent"]
            ?: throw Exception("Missing User-Agent")

        CookieManager.getInstance().flush()
        logClearance(base)

        Log.i(TAG, "AllManga-style loadData manga=$mangaUrl chapterPath=$chapterPath")

        val document = source.client.newCall(
            Request.Builder().url(mangaUrl).headers(source.headers).get().build(),
        ).execute().use { response ->
            if (!response.isSuccessful) {
                if (response.code == 403 || response.code == 503) {
                    throw Exception(captchaMessage)
                }
                throw Exception("HTTP error ${response.code}")
            }
            response.asJsoup().also { doc ->
                val html = doc.html()
                if (looksLikeCloudflareChallenge(html)) {
                    throw Exception(captchaMessage)
                }
                doc.head().prepend(buildHeadHooks(interfaceName))
            }
        }

        val payload = try {
            runWebView<String>(timeout = 45.seconds) {
                // Same as released AllManga / Mihon path.
                blockImages = true
                userAgent = ua

                jsBridge(interfaceName) { message ->
                    Log.i(TAG, "chapterPages bridge len=${message.length}")
                    resolve(message)
                }

                val clickScript = """
                (function () {
                    function triggerChapterNav() {
                        const a = document.createElement('a');
                        a.href = a.dataset.href = '$chapterPath';
                        document.body.append(a);
                        a.click();
                    }

                   let checkAttempts = 0;
                   const maxAttempts = 300;

                   function check() {
                       if (document.querySelector('[data-href]')) {
                           triggerChapterNav();
                       } else if (checkAttempts < maxAttempts) {
                           checkAttempts++;
                           setTimeout(check, 50);
                       } else {
                           triggerChapterNav();
                       }
                   }
                   check();
                })();
                """.trimIndent()

                // Re-install capture hooks if a soft/hard nav replaces the document.
                val reinstallHooks = buildReinstallHooks(interfaceName)

                onPageStarted { url ->
                    Log.d(TAG, "onPageStarted $url")
                    evaluateJs(reinstallHooks)
                    evaluateJs(clickScript)
                }

                // Fail fast if Turnstile appears (cannot be solved headless).
                poll(interval = 1500.milliseconds) {
                    evaluateJs(CHALLENGE_DETECT_JS) { value ->
                        if (value == "true" || value == "\"true\"") {
                            reject(Exception(captchaMessage))
                        }
                    }
                }

                // Host loadData injects ServiceWorker stub (see keiyoushi.utils.WebView).
                loadData(mangaUrl, document.outerHtml())
            }
        } catch (e: WebViewTimeoutException) {
            throw Exception(
                "Timed out loading pages (Cloudflare?). Open the source in WebView, " +
                    "solve the captcha, then retry.",
                e,
            )
        }

        return parseChapterPages(payload)
    }

    private fun logClearance(baseUrl: String) {
        val cookies = CookieManager.getInstance().getCookie(baseUrl).orEmpty()
        val hasClearance = cookies.contains("cf_clearance=")
        Log.i(
            TAG,
            "cookies for $baseUrl: cf_clearance=${if (hasClearance) "yes" else "NO"} " +
                "len=${cookies.length}",
        )
    }

    /**
     * AllManga head hooks (Response.json + JSON.parse + iframe contentWindow null),
     * plus fetch/XHR so we still catch chapterPages if the SPA avoids Response.json.
     */
    private fun buildHeadHooks(interfaceName: String): String =
        """
        <script>
        (() => {
            window.__komaMkissaHooks = true;
            const postPages = (obj, raw) => {
                try {
                    if (!obj) return;
                    if (obj.chapterPages) {
                        window.$interfaceName.post(raw || JSON.stringify(obj));
                        return;
                    }
                    if (obj.data && obj.data.chapterPages) {
                        window.$interfaceName.post(JSON.stringify(obj.data));
                    }
                } catch (e) {}
            };

            const originalJson = Response.prototype.json;
            Response.prototype.json = function() {
                return originalJson.call(this).then(data => {
                    postPages(data);
                    return data;
                });
            };

            const originalParse = JSON.parse;
            JSON.parse = new Proxy(originalParse, {
                apply(target, thisArg, args) {
                    const result = Reflect.apply(target, thisArg, args);
                    postPages(result, typeof args[0] === 'string' ? args[0] : undefined);
                    return result;
                }
            });

            try {
                const origFetch = window.fetch;
                window.fetch = function() {
                    return origFetch.apply(this, arguments).then(function(res) {
                        try {
                            const clone = res.clone();
                            clone.text().then(function(t) {
                                if (t && t.indexOf('chapterPages') !== -1) {
                                    try { postPages(JSON.parse(t), t); }
                                    catch (e) { window.$interfaceName.post(t); }
                                }
                            });
                        } catch (e) {}
                        return res;
                    });
                };
            } catch (e) {}

            try {
                const xhrSend = XMLHttpRequest.prototype.send;
                XMLHttpRequest.prototype.send = function() {
                    this.addEventListener('load', function() {
                        try {
                            const t = this.responseText;
                            if (t && t.indexOf('chapterPages') !== -1) {
                                try { postPages(JSON.parse(t), t); }
                                catch (e) { window.$interfaceName.post(t); }
                            }
                        } catch (e) {}
                    });
                    return xhrSend.apply(this, arguments);
                };
            } catch (e) {}

            // AllManga blanks tracking iframes. Safe on loadData after CF is cleared
            // via OkHttp — do not use loadUrl(chapter) or Turnstile never finishes.
            const hook = e => {
                if (e.tagName && e.tagName.toUpperCase() === "IFRAME") {
                    Object.defineProperty(e, "contentWindow", {
                        get: () => null,
                        configurable: false
                    });
                }
                return e;
            };

            for (const k of ["createElement", "createElementNS"]) {
                const c = Document.prototype[k];
                Document.prototype[k] = function(...a) {
                    return hook(c.call(this, ...a));
                };
            }
        })();
        </script>
        """.trimIndent()

    /** Idempotent re-install after navigations (no iframe hook — Turnstile may appear). */
    private fun buildReinstallHooks(interfaceName: String): String =
        """
        (function(){
          if (window.__komaMkissaHooks) return;
          window.__komaMkissaHooks = true;
          function postPages(obj, raw) {
            try {
              if (!obj) return;
              if (obj.chapterPages) {
                window.$interfaceName.post(raw || JSON.stringify(obj));
                return;
              }
              if (obj.data && obj.data.chapterPages) {
                window.$interfaceName.post(JSON.stringify(obj.data));
              }
            } catch (e) {}
          }
          try {
            var originalJson = Response.prototype.json;
            Response.prototype.json = function() {
              return originalJson.call(this).then(function(data) {
                postPages(data);
                return data;
              });
            };
          } catch (e) {}
          try {
            var originalParse = JSON.parse;
            JSON.parse = function(text, reviver) {
              var result = originalParse.call(this, text, reviver);
              postPages(result, typeof text === 'string' ? text : undefined);
              return result;
            };
          } catch (e) {}
          try {
            var origFetch = window.fetch;
            window.fetch = function() {
              return origFetch.apply(this, arguments).then(function(res) {
                try {
                  var clone = res.clone();
                  clone.text().then(function(t) {
                    if (t && t.indexOf('chapterPages') !== -1) {
                      try { postPages(JSON.parse(t), t); }
                      catch (e) { window.$interfaceName.post(t); }
                    }
                  });
                } catch (e) {}
                return res;
              });
            };
          } catch (e) {}
        })();
        """.trimIndent()

    private val CHALLENGE_DETECT_JS =
        """
        (function(){
          try {
            var u = location.href || '';
            if (u.indexOf('cdn-cgi/challenge') !== -1) return true;
            if (document.querySelector(
              '#challenge-form, #challenge-error-title, #challenge-error-text, iframe[src*="challenges.cloudflare"], iframe[src*="turnstile"]'
            )) return true;
            var t = (document.body && document.body.innerText) || '';
            if (/just a moment/i.test(t)) return true;
          } catch (e) {}
          return false;
        })();
        """.trimIndent()

    private fun looksLikeCloudflareChallenge(html: String): Boolean {
        val h = html.lowercase()
        return "cf-browser-verification" in h ||
            "challenge-platform" in h ||
            "cdn-cgi/challenge" in h ||
            "just a moment" in h ||
            ("turnstile" in h && "cloudflare" in h)
    }

    private fun parseChapterPages(payload: String): List<Page> {
        val root = json.parseToJsonElement(payload).jsonObject
        val chapterPages = root["chapterPages"]?.jsonObject
            ?: root["data"]?.jsonObject?.get("chapterPages")?.jsonObject
            ?: return emptyList()
        val edges = chapterPages["edges"]?.jsonArray ?: return emptyList()
        if (edges.isEmpty()) return emptyList()

        fun edgeScore(edge: JsonObject): Int {
            val pictures = edge["pictureUrls"] as? JsonArray ?: return 0
            val full = pictures.any { pic ->
                (pic as? JsonObject)?.get("url").asString()?.matches(urlRegex) == true
            }
            val server = edge["pictureUrlHead"].asString() != null
            return when {
                full || server -> 2
                pictures.isNotEmpty() -> 1
                else -> 0
            }
        }

        val best = edges.mapNotNull { it as? JsonObject }
            .maxByOrNull(::edgeScore)
            ?: return emptyList()

        val pictureUrls = (best["pictureUrls"] as? JsonArray).orEmpty()
        val server = best["pictureUrlHead"].asString()
        val imageDomain = when {
            server == null -> "https://ytimgf.youtube-anime.com/"
            server.matches(urlRegex) -> server.trimEnd('/') + "/"
            else -> "https://${server.trimEnd('/')}/"
        }

        return pictureUrls.mapIndexedNotNull { index, el ->
            val path = (el as? JsonObject)?.get("url").asString() ?: return@mapIndexedNotNull null
            val imageUrl = if (path.matches(urlRegex)) path else imageDomain + path.removePrefix("/")
            Page(index = index, url = imageUrl, imageUrl = imageUrl)
        }
    }

    private fun randomBridgeName(): String =
        (1..(10..20).random())
            .map { (('a'..'z') + ('A'..'Z')).random() }
            .joinToString("")

    private fun kotlinx.serialization.json.JsonElement?.asString(): String? =
        when (this) {
            null -> null
            is JsonPrimitive -> contentOrNull
            else -> null
        }
}
