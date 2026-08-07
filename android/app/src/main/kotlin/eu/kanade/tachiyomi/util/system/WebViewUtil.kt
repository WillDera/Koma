package eu.kanade.tachiyomi.util.system

import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.webkit.CookieManager
import android.webkit.WebSettings
import android.webkit.WebView

object WebViewUtil {
    private const val CHROME_PACKAGE = "com.android.chrome"
    private const val YOUTUBE_FOR_TV_PACKAGE = "com.google.android.youtube.tv"
    private const val SYSTEM_SETTINGS_PACKAGE = "com.android.settings"

    const val MINIMUM_WEBVIEW_VERSION = 118

    /**
     * Prefer a Chrome-on-Android style UA (Mihon parity). Cloudflare / AllManga
     * bind `cf_clearance` to this exact string — stub UAs break extension runWebView.
     */
    @SuppressLint("SetJavaScriptEnabled")
    fun getInferredUserAgent(context: Context): String {
        return WebView(context)
            .getDefaultUserAgentString()
            .replace("; Android .*?\\)".toRegex(), "; Android 10; K)")
            .replace("Version/.* Chrome/".toRegex(), "Chrome/")
    }

    fun getVersion(context: Context): String {
        val webView = WebView.getCurrentWebViewPackage() ?: return "unknown"
        val pm = context.packageManager
        val label = webView.applicationInfo!!.loadLabel(pm)
        val version = webView.versionName
        return "$label $version"
    }

    fun supportsWebView(context: Context): Boolean {
        try {
            CookieManager.getInstance()
        } catch (e: Throwable) {
            return false
        }
        return context.packageManager.hasSystemFeature(PackageManager.FEATURE_WEBVIEW)
    }

    fun spoofedPackageName(context: Context): String {
        return runCatching { context.packageManager.getPackageInfo(CHROME_PACKAGE, 0) }
            .recoverCatching { context.packageManager.getPackageInfo(SYSTEM_SETTINGS_PACKAGE, 0) }
            .recoverCatching { context.packageManager.getPackageInfo(YOUTUBE_FOR_TV_PACKAGE, 0) }
            .fold(
                onSuccess = { it.packageName },
                onFailure = {
                    context.packageManager.getInstalledPackages(0).random().packageName
                },
            )
    }
}

fun WebView.isOutdated(): Boolean {
    return getWebViewMajorVersion() < WebViewUtil.MINIMUM_WEBVIEW_VERSION
}

@SuppressLint("SetJavaScriptEnabled")
fun WebView.setDefaultSettings() {
    with(settings) {
        javaScriptEnabled = true
        domStorageEnabled = true
        useWideViewPort = true
        loadWithOverviewMode = true
        cacheMode = WebSettings.LOAD_DEFAULT
        setSupportMultipleWindows(true)
        setSupportZoom(true)
        builtInZoomControls = true
        displayZoomControls = false
    }
    CookieManager.getInstance().acceptThirdPartyCookies(this)
}

private fun WebView.getWebViewMajorVersion(): Int {
    val uaRegexMatch = """.*Chrome/(\d+)\..*""".toRegex().matchEntire(getDefaultUserAgentString())
    return if (uaRegexMatch != null && uaRegexMatch.groupValues.size > 1) {
        uaRegexMatch.groupValues[1].toInt()
    } else {
        0
    }
}

// Based on https://stackoverflow.com/a/29218966
fun WebView.getDefaultUserAgentString(): String {
    val originalUA: String = settings.userAgentString
    settings.userAgentString = null
    val defaultUserAgentString = settings.userAgentString
    settings.userAgentString = originalUA
    return defaultUserAgentString
}
