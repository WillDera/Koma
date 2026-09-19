package eu.kanade.tachiyomi.util.system

import dalvik.system.PathClassLoader
import java.io.IOException
import java.io.InputStream
import java.net.URL
import java.util.Enumeration

/**
 * Parent-last classloader matching Mihon's approach, with host overrides:
 * - [keiyoushi.utils] WebView helpers always load from the app ClassLoader so our
 *   ServiceWorker stub for loadDataWithBaseURL is used (extension APK has an
 *   unpatched copy that would otherwise win under child-first).
 * - Shared runtime packages (`kotlin.*`, `kotlinx.*`, OkHttp, Jsoup, …) always
 *   load from the host. Extensions do not ship kotlin-stdlib; if R8 or a
 *   partial DEX copy wins child-first, you get
 *   `Failed resolution of: Lkotlin/text/Regex;`.
 */
class ChildFirstPathClassLoader(
    dexPath: String,
    librarySearchPath: String?,
    parent: ClassLoader,
) : PathClassLoader(dexPath, librarySearchPath, parent) {

    private val systemClassLoader: ClassLoader? = getSystemClassLoader()

    override fun loadClass(name: String?, resolve: Boolean): Class<*> {
        var c = findLoadedClass(name)

        // Host-shared / host-patched types MUST win over anything in the APK.
        if (c == null && name != null && prefersHostClass(name)) {
            val host = parent
                ?: throw ClassNotFoundException("no parent ClassLoader for $name")
            c = host.loadClass(name)
            if (resolve) resolveClass(c)
            return c
        }

        if (c == null && systemClassLoader != null) {
            try {
                c = systemClassLoader.loadClass(name)
            } catch (_: ClassNotFoundException) {}
        }

        if (c == null) {
            if (name != null && name.startsWith("uy.kohesive.injekt.")) {
                try {
                    c = super.loadClass(name, resolve)
                } catch (_: ClassNotFoundException) {
                    c = findClass(name)
                }
            } else {
                try {
                    c = findClass(name)
                } catch (_: ClassNotFoundException) {
                    c = super.loadClass(name, resolve)
                }
            }
        }

        if (resolve) {
            resolveClass(c)
        }

        return c
    }

    override fun getResource(name: String?): URL? {
        return systemClassLoader?.getResource(name)
            ?: findResource(name)
            ?: super.getResource(name)
    }

    override fun getResources(name: String?): Enumeration<URL> {
        val systemUrls = systemClassLoader?.getResources(name)
        val localUrls = findResources(name)
        val parentUrls = parent?.getResources(name)
        val urls = buildList {
            while (systemUrls?.hasMoreElements() == true) {
                add(systemUrls.nextElement())
            }
            while (localUrls?.hasMoreElements() == true) {
                add(localUrls.nextElement())
            }
            while (parentUrls?.hasMoreElements() == true) {
                add(parentUrls.nextElement())
            }
        }
        return object : Enumeration<URL> {
            val iterator = urls.iterator()
            override fun hasMoreElements() = iterator.hasNext()
            override fun nextElement() = iterator.next()
        }
    }

    override fun getResourceAsStream(name: String?): InputStream? {
        return try {
            getResource(name)?.openStream()
        } catch (_: IOException) {
            return null
        }
    }

    companion object {
        /** Packages that must come from the host APK, not the extension DEX. */
        fun prefersHostClass(name: String): Boolean {
            if (prefersHostWebView(name)) return true
            return name.startsWith("kotlin.") ||
                name.startsWith("kotlinx.") ||
                name.startsWith("okhttp3.") ||
                name.startsWith("okio.") ||
                name.startsWith("org.jsoup.") ||
                name.startsWith("rx.") ||
                name.startsWith("io.reactivex.") ||
                name.startsWith("androidx.preference.") ||
                name.startsWith("com.squareup.zstd.")
        }

        /** Host-shipped keiyoushi WebView.kt symbols (see keiyoushi/utils/WebView.kt). */
        fun prefersHostWebView(name: String): Boolean {
            if (!name.startsWith("keiyoushi.utils.")) return false
            val simple = name.removePrefix("keiyoushi.utils.")
            // Match Kotlin file facade, nested classes, and any WebView* type.
            return simple == "WebViewKt" ||
                simple.startsWith("WebViewKt\$") ||
                simple.startsWith("WebView") ||
                simple == "RenderProcessGoneException" ||
                simple == "WebViewTimeoutException" ||
                simple.startsWith("ScopeWebViewClient") ||
                simple.startsWith("LoggingWebChromeClient") ||
                simple.contains("ServiceWorkerStub") ||
                simple == "InjectServiceWorkerStubKt" // if top-level was split
        }
    }
}
