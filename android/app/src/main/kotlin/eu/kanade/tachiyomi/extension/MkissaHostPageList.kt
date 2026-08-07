package eu.kanade.tachiyomi.extension

import android.util.Log
import eu.kanade.tachiyomi.source.model.Page
import eu.kanade.tachiyomi.source.model.SChapter
import eu.kanade.tachiyomi.source.online.HttpSource
import eu.kanade.tachiyomi.util.asJsoup
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
import kotlin.time.Duration.Companion.seconds

/**
 * Host-owned page-list fetch for AllManga / mkissa.
 *
 * The extension APK R8-obfuscates its `runWebView` into a private class, so we cannot
 * patch it via ClassLoader. Instead we reimplement AllManga's [getPageList] here using
 * the host [keiyoushi.utils.runWebView] — same OkHttp HTML fetch + head hooks +
 * [loadData] + synthetic chapter click that Mihon runs successfully.
 *
 * Cloudflare: if OkHttp gets 403/503, tell the user to use Open in WebView (same as
 * the extension's own message). Do not auto-dump into an interactive reader WebView.
 */
object MkissaHostPageList {
    private const val TAG = "MkissaHostPageList"

    /** Mihon numeric id seen in logs for en AllManga (`2e5cd659b0172a4c`). */
    private const val ALLMANGA_EN_ID = 4709139914729853090L

    private val urlRegex = Regex("^https?://.*")
    private val json = Json { ignoreUnknownKeys = true; isLenient = true }

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

        Log.i(TAG, "AllManga-style loadData manga=$mangaUrl chapterPath=$chapterPath")

        val document = source.client.newCall(
            Request.Builder().url(mangaUrl).headers(source.headers).get().build(),
        ).execute().use { response ->
            if (!response.isSuccessful) {
                if (response.code == 403 || response.code == 503) {
                    throw Exception("Solve captcha in WebView and retry")
                }
                throw Exception("HTTP error ${response.code}")
            }
            response.asJsoup().also { doc ->
                doc.head().prepend(
                    """
                    <script>
                    (() => {
                        const originalJson = Response.prototype.json;
                        Response.prototype.json = function() {
                            return originalJson.call(this).then(data => {
                                if (data && data.chapterPages) {
                                    window.$interfaceName.post(JSON.stringify(data));
                                }
                                return data;
                            });
                        };

                        const originalParse = JSON.parse;
                        JSON.parse = new Proxy(originalParse, {
                            apply(target, thisArg, args) {
                                const result = Reflect.apply(target, thisArg, args);
                                if (result && result.chapterPages) {
                                    window.$interfaceName.post(args[0]);
                                }
                                return result;
                            }
                        });

                      const hook = e => {
                        if (e.tagName.toUpperCase() === "IFRAME") {
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
                    """.trimIndent(),
                )
            }
        }

        val payload = runWebView<String>(timeout = 45.seconds) {
            blockImages = true
            userAgent = ua

            val script = """
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

            jsBridge(interfaceName) { message ->
                resolve(message)
            }

            onPageStarted {
                evaluateJs(script)
            }

            // Host loadData injects ServiceWorker stub (see keiyoushi.utils.WebView).
            loadData(mangaUrl, document.outerHtml())
        }

        return parseChapterPages(payload)
    }

    private fun parseChapterPages(payload: String): List<Page> {
        val root = json.parseToJsonElement(payload).jsonObject
        val edges = root["chapterPages"]?.jsonObject?.get("edges")?.jsonArray
            ?: return emptyList()
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
            Page(index = index, imageUrl = imageUrl)
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
