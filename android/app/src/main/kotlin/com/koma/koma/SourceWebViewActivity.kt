package com.koma.koma

import android.annotation.SuppressLint
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.net.Uri
import android.os.Bundle
import android.util.Log
import android.view.Menu
import android.view.MenuItem
import android.view.View
import android.webkit.CookieManager
import android.webkit.WebChromeClient
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.ProgressBar
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.appcompat.widget.Toolbar
import androidx.core.view.ViewCompat
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import eu.kanade.tachiyomi.extension.DalvikRuntimeManager
import eu.kanade.tachiyomi.extension.DalvikServer
import eu.kanade.tachiyomi.network.NetworkHelper
import eu.kanade.tachiyomi.source.model.SManga
import eu.kanade.tachiyomi.source.online.HttpSource
import eu.kanade.tachiyomi.util.system.WebViewUtil
import eu.kanade.tachiyomi.util.system.setDefaultSettings
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonObject
import mihon.core.common.extensions.EMPTY
import okhttp3.HttpUrl.Companion.toHttpUrlOrNull
import uy.kohesive.injekt.Injekt
import uy.kohesive.injekt.api.get

/**
 * Mihon-parity interactive WebView for solving Cloudflare / site captchas.
 * Cookies land in [CookieManager] (shared with OkHttp / extensions).
 * User-Agent must match [NetworkHelper.defaultUserAgentProvider] so cf_clearance applies.
 *
 * Open from manga detail → Open in WebView, solve the challenge, then retry the chapter.
 */
class SourceWebViewActivity : AppCompatActivity() {

    private lateinit var webView: WebView
    private lateinit var progress: ProgressBar
    private var currentUrl: String = ""
    private var headers: Map<String, String> = emptyMap()

    @SuppressLint("SetJavaScriptEnabled")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        if (!WebViewUtil.supportsWebView(this)) {
            Toast.makeText(this, R.string.webview_required, Toast.LENGTH_LONG).show()
            finish()
            return
        }

        setContentView(R.layout.activity_source_webview)
        WindowCompat.setDecorFitsSystemWindows(window, false)
        val root = findViewById<View>(R.id.source_webview_root)
        ViewCompat.setOnApplyWindowInsetsListener(root) { view, insets ->
            val bars = insets.getInsets(WindowInsetsCompat.Type.systemBars())
            view.setPadding(bars.left, bars.top, bars.right, bars.bottom)
            insets
        }

        val toolbar = findViewById<Toolbar>(R.id.toolbar)
        setSupportActionBar(toolbar)
        supportActionBar?.setDisplayHomeAsUpEnabled(true)
        supportActionBar?.title =
            intent.getStringExtra(EXTRA_TITLE)?.ifBlank { null }
                ?: getString(R.string.webview_title)

        progress = findViewById(R.id.progress)
        webView = findViewById(R.id.webview)
        webView.setDefaultSettings()
        CookieManager.getInstance().setAcceptCookie(true)
        CookieManager.getInstance().setAcceptThirdPartyCookies(webView, true)

        webView.webViewClient = object : WebViewClient() {
            override fun onPageStarted(view: WebView?, url: String?, favicon: Bitmap?) {
                progress.visibility = View.VISIBLE
                url?.let {
                    currentUrl = it
                    supportActionBar?.subtitle = it
                }
            }

            override fun onPageFinished(view: WebView?, url: String?) {
                progress.visibility = View.GONE
                url?.let { currentUrl = it }
                CookieManager.getInstance().flush()
            }

            override fun shouldOverrideUrlLoading(
                view: WebView?,
                request: WebResourceRequest?,
            ): Boolean {
                val url = request?.url?.toString() ?: return false
                if (url.startsWith("intent://") || url.startsWith("mailto:")) return true
                if (url.startsWith("http://") || url.startsWith("https://")) {
                    view?.loadUrl(url, headers)
                    return true
                }
                return false
            }
        }
        webView.webChromeClient = object : WebChromeClient() {
            override fun onProgressChanged(view: WebView?, newProgress: Int) {
                progress.visibility = if (newProgress in 1..99) View.VISIBLE else View.GONE
            }
        }

        Thread {
            val resolved = resolveLoadTarget()
            runOnUiThread {
                if (resolved == null) {
                    Toast.makeText(this, R.string.webview_url_failed, Toast.LENGTH_LONG).show()
                    finish()
                    return@runOnUiThread
                }
                currentUrl = resolved.first
                headers = resolved.second
                val ua = headers["User-Agent"]
                    ?: headers["user-agent"]
                    ?: runCatching { Injekt.get<NetworkHelper>().defaultUserAgentProvider() }
                        .getOrDefault(NetworkHelper.FALLBACK_USER_AGENT)
                webView.settings.userAgentString = ua
                supportActionBar?.subtitle = currentUrl
                webView.loadUrl(currentUrl, headers)
            }
        }.start()
    }

    /**
     * Prefer [HttpSource.getMangaUrl] (AllManga builds `/manga/$id` correctly).
     * Fall back to an absolute URL passed from Flutter.
     */
    private fun resolveLoadTarget(): Pair<String, Map<String, String>>? {
        val rawUrl = intent.getStringExtra(EXTRA_URL).orEmpty()
        val sourceId = intent.getStringExtra(EXTRA_SOURCE_ID).orEmpty()
        val memoJson = intent.getStringExtra(EXTRA_MEMO)

        try {
            DalvikRuntimeManager.initialize(applicationContext)
            DalvikRuntimeManager.getOrStartServer()
        } catch (e: Throwable) {
            Log.w(TAG, "server start failed", e)
        }

        var headerMap = emptyMap<String, String>()
        var pageUrl = rawUrl

        if (sourceId.isNotBlank()) {
            try {
                val source = DalvikServer.getInstance().findHttpSource(sourceId)
                if (source is HttpSource) {
                    headerMap = source.headers.toMultimap()
                        .mapValues { it.value.firstOrNull().orEmpty() }
                        .filterValues { it.isNotEmpty() }
                    val manga = SManga.create().apply {
                        url = rawUrl
                        title = intent.getStringExtra(EXTRA_TITLE).orEmpty()
                        if (!memoJson.isNullOrBlank()) {
                            memo = runCatching {
                                Json.parseToJsonElement(memoJson).jsonObject
                            }.getOrDefault(JsonObject.EMPTY)
                        }
                    }
                    pageUrl = source.getMangaUrl(manga)
                }
            } catch (e: Throwable) {
                Log.e(TAG, "resolve manga url failed", e)
            }
        }

        if (pageUrl.isBlank()) return null
        if (!pageUrl.startsWith("http://") && !pageUrl.startsWith("https://")) {
            Log.e(TAG, "non-absolute url: $pageUrl")
            return null
        }
        return pageUrl to headerMap
    }

    override fun onCreateOptionsMenu(menu: Menu): Boolean {
        menu.add(0, MENU_BACK, 0, R.string.webview_back).setShowAsAction(MenuItem.SHOW_AS_ACTION_NEVER)
        menu.add(0, MENU_FORWARD, 1, R.string.webview_forward).setShowAsAction(MenuItem.SHOW_AS_ACTION_NEVER)
        menu.add(0, MENU_REFRESH, 2, R.string.webview_refresh).setShowAsAction(MenuItem.SHOW_AS_ACTION_NEVER)
        menu.add(0, MENU_CLEAR_COOKIES, 3, R.string.webview_clear_cookies)
            .setShowAsAction(MenuItem.SHOW_AS_ACTION_NEVER)
        menu.add(0, MENU_OPEN_BROWSER, 4, R.string.webview_open_browser)
            .setShowAsAction(MenuItem.SHOW_AS_ACTION_NEVER)
        return true
    }

    override fun onOptionsItemSelected(item: MenuItem): Boolean {
        when (item.itemId) {
            android.R.id.home -> {
                finish()
                return true
            }
            MENU_BACK -> {
                if (webView.canGoBack()) webView.goBack()
                return true
            }
            MENU_FORWARD -> {
                if (webView.canGoForward()) webView.goForward()
                return true
            }
            MENU_REFRESH -> {
                webView.reload()
                return true
            }
            MENU_CLEAR_COOKIES -> {
                clearCookies(currentUrl)
                Toast.makeText(this, R.string.webview_cookies_cleared, Toast.LENGTH_SHORT).show()
                webView.reload()
                return true
            }
            MENU_OPEN_BROWSER -> {
                try {
                    startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(currentUrl)))
                } catch (e: Throwable) {
                    Toast.makeText(this, e.message, Toast.LENGTH_SHORT).show()
                }
                return true
            }
        }
        return super.onOptionsItemSelected(item)
    }

    private fun clearCookies(url: String) {
        val httpUrl = url.toHttpUrlOrNull() ?: return
        try {
            Injekt.get<NetworkHelper>().cookieJar.remove(httpUrl)
        } catch (e: Throwable) {
            Log.w(TAG, "cookie clear via jar failed", e)
            CookieManager.getInstance().removeAllCookies(null)
        }
        CookieManager.getInstance().flush()
    }

    override fun onSupportNavigateUp(): Boolean {
        finish()
        return true
    }

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        if (webView.canGoBack()) {
            webView.goBack()
        } else {
            @Suppress("DEPRECATION")
            super.onBackPressed()
        }
    }

    override fun onDestroy() {
        runCatching { CookieManager.getInstance().flush() }
        if (::webView.isInitialized) {
            runCatching {
                webView.stopLoading()
                webView.destroy()
            }
        }
        super.onDestroy()
    }

    companion object {
        private const val TAG = "SourceWebView"
        private const val EXTRA_URL = "url"
        private const val EXTRA_SOURCE_ID = "source_id"
        private const val EXTRA_TITLE = "title"
        private const val EXTRA_MEMO = "memo"

        private const val MENU_BACK = 1
        private const val MENU_FORWARD = 2
        private const val MENU_REFRESH = 3
        private const val MENU_CLEAR_COOKIES = 4
        private const val MENU_OPEN_BROWSER = 5

        fun intent(
            context: Context,
            url: String,
            sourceId: String?,
            title: String?,
            memo: String? = null,
        ): Intent {
            return Intent(context, SourceWebViewActivity::class.java).apply {
                putExtra(EXTRA_URL, url)
                if (!sourceId.isNullOrBlank()) putExtra(EXTRA_SOURCE_ID, sourceId)
                if (!title.isNullOrBlank()) putExtra(EXTRA_TITLE, title)
                if (!memo.isNullOrBlank()) putExtra(EXTRA_MEMO, memo)
            }
        }
    }
}
