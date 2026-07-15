package eu.kanade.tachiyomi.extension

import android.content.Context
import dalvik.system.DexClassLoader
import eu.kanade.tachiyomi.source.Source
import java.io.File
import java.util.concurrent.ConcurrentHashMap

/**
 * Loads Keiyoushi/Mihon extension APKs at runtime.
 *
 * Pipeline (per Android 14 Dynamic Code Loading requirements):
 *  1. Caller has already downloaded the APK to internal storage (we don't
 *     download here — the Dart `extension_manager` owns that path).
 *  2. We mark the APK and its parent directory read-only.
 *  3. We pick (or create) a writable-but-locked-down optimized-dex
 *     directory and mark it read-only.
 *  4. We instantiate [DexClassLoader] with the host classloader as
 *     parent so the extension can resolve `eu.kanade.tachiyomi.*`
 *     types from this app's classpath.
 *  5. We reflect the named Source class to a no-arg constructor and
 *     cast to [Source].
 *
 * Loaders are cached by apkPath so re-installing the same APK doesn't
 * spin up duplicate classloaders.
 */
class ExtensionLoader(private val context: Context) {

    private val loaderByApkPath: MutableMap<String, DexClassLoader> = ConcurrentHashMap()
    private val classByFqn: MutableMap<String, Class<*>> = ConcurrentHashMap()

    /**
     * Load a [Source] from an APK on disk.
     *
     * @param apkPath Absolute path to a Keiyoushi extension APK.
     * @param className Fully-qualified Java class name of the Source
     *   subclass (e.g. `eu.kanade.tachiyomi.extension.en.mangapill.MangaPill`).
     *   Extensions declare this via the `<meta-data
     *   android:name="tachiyomi.extension.class">` tag in their manifest.
     */
    fun loadFromApk(apkPath: String, className: String): Source {
        val apkFile = File(apkPath)
        require(apkFile.exists()) { "APK not found: $apkPath" }
        require(apkFile.canRead()) { "APK not readable: $apkPath" }

        // Cache hit — class already loaded, just instantiate.
        classByFqn[className]?.let { cached ->
            return instantiate(cached)
        }

        enforceReadOnly(apkFile, "apk file")
        enforceReadOnly(apkFile.parentFile, "apk parent dir")

        val optDir = ensureOptimizedDir(apkFile.nameWithoutExtension)
        enforceReadOnly(optDir, "optimized dir")

        val classLoader = DexClassLoader(
            apkPath,
            optDir.absolutePath,
            /* librarySearchPath = */ null,
            /* parent = */ context.classLoader,
        )
        loaderByApkPath[apkPath] = classLoader

        val clazz = classLoader.loadClass(className)
        require(Source::class.java.isAssignableFrom(clazz)) {
            "$className does not implement Source"
        }
        @Suppress("UNCHECKED_CAST")
        classByFqn[className] = clazz

        return instantiate(clazz)
    }

    /** Unload everything from a given APK. The JVM will GC the
     *  classloader (and its loaded classes) once the references drop. */
    fun unloadApk(apkPath: String) {
        loaderByApkPath.remove(apkPath)?.let { loader ->
            // Drop cached class refs that came from this loader.
            classByFqn.entries.removeAll { it.value.classLoader === loader }
        }
    }

    fun isLoaded(apkPath: String): Boolean = loaderByApkPath.containsKey(apkPath)

    fun loadedApkPaths(): Set<String> = loaderByApkPath.keys.toSet()

    // -- Internals -------------------------------------------------------

    private fun instantiate(clazz: Class<*>): Source {
        val ctor = clazz.getDeclaredConstructor()
        ctor.isAccessible = true
        return ctor.newInstance() as Source
    }

    private fun ensureOptimizedDir(name: String): File {
        val dir = File(context.codeCacheDir, "ext_dex_$name")
        if (!dir.exists() && !dir.mkdirs()) {
            throw IllegalStateException("Failed to create optimized dir: ${dir.absolutePath}")
        }
        return dir
    }

    /**
     * Android 14 DCL: dynamically-loaded code files (and the parent
     * directory) must be read-only. Older Androids ignore setReadOnly()
     * when the bit is already set, so calling it unconditionally is safe.
     */
    private fun enforceReadOnly(file: File?, label: String) {
        if (file == null) return
        try {
            // setReadOnly() returns false on failure; we don't care
            // about the result — the loader will surface a real error
            // if the platform actually rejects us.
            file.setReadOnly()
        } catch (_: SecurityException) {
            // Some OEM ROMs refuse; let DexClassLoader complain.
        }
    }
}
