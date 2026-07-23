package eu.kanade.tachiyomi.extension

import android.content.Context
import android.content.pm.PackageManager
import android.util.Log
import eu.kanade.tachiyomi.source.Source
import eu.kanade.tachiyomi.source.SourceFactory
import eu.kanade.tachiyomi.source.online.HttpSource
import eu.kanade.tachiyomi.util.system.ChildFirstPathClassLoader
import java.io.File
import java.util.concurrent.ConcurrentHashMap

class ExtensionLoader(private val context: Context) {

    companion object {
        private const val TAG = "ExtLoader"
        // Keiyoushi extensions encode lib version in versionName: "1.4.35" → 1.4
        private const val LIB_VERSION_MIN = 1.4
        private const val LIB_VERSION_MAX = 1.5
    }

    private val loaderByApkPath: MutableMap<String, ClassLoader> = ConcurrentHashMap()

    fun loadFromApk(apkPath: String, className: String): Source {
        Log.d(TAG, "loadFromApk: apkPath=$apkPath className=$className")

        val apkFile = File(apkPath)
        if (!apkFile.exists()) {
            Log.e(TAG, "APK not found: $apkPath")
            throw IllegalArgumentException("APK not found: $apkPath")
        }
        if (!apkFile.canRead()) {
            Log.e(TAG, "APK not readable: $apkPath")
            throw IllegalArgumentException("APK not readable: $apkPath")
        }

        val resolvedClassName = if (className.startsWith(".")) {
            val pkg = context.packageManager.getPackageArchiveInfo(apkPath, 0)?.packageName
                ?: throw IllegalArgumentException("Cannot resolve relative class name without package info: $className")
            val resolved = pkg + className
            Log.d(TAG, "Resolved relative class: $className → $resolved")
            resolved
        } else {
            className
        }
        Log.d(TAG, "Resolved class name: $resolvedClassName")

        // Validate lib version from extension's versionName
        val pkgInfo = context.packageManager.getPackageArchiveInfo(apkPath, 0)
        if (pkgInfo != null) {
            val vName = pkgInfo.versionName
            Log.d(TAG, "Extension package: ${pkgInfo.packageName} versionName=$vName versionCode=${pkgInfo.longVersionCode}")
            if (vName != null) {
                val libVer = vName.substringBeforeLast('.').toDoubleOrNull()
                if (libVer != null && (libVer < LIB_VERSION_MIN || libVer > LIB_VERSION_MAX)) {
                    Log.w(TAG, "Lib version $libVer out of range [$LIB_VERSION_MIN, $LIB_VERSION_MAX]")
                }
            }
        }

        // Check meta-data for additional source class hints
        val pm = context.packageManager
        val archiveInfo = pm.getPackageArchiveInfo(apkPath, PackageManager.GET_META_DATA)
        archiveInfo?.applicationInfo?.sourceDir = apkPath
        val metaData = archiveInfo?.applicationInfo?.metaData
        if (metaData != null) {
            val sourceClass = metaData.getString("tachiyomi.extension.class")
            val sourceFactory = metaData.getString("tachiyomi.extension.factory")
            val nsfw = metaData.getInt("tachiyomi.extension.nsfw", 0)
            Log.d(TAG, "Manifest: class=$sourceClass factory=$sourceFactory nsfw=$nsfw")
        }

        enforceReadOnly(apkFile, "apk file")

        val classLoader = try {
            ChildFirstPathClassLoader(
                apkPath,
                null,
                context.classLoader,
            ).also { Log.d(TAG, "Created ChildFirstPathClassLoader parent=${context.classLoader}") }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to create ChildFirstPathClassLoader", e)
            throw RuntimeException("Failed to create classloader for $apkPath", e)
        }
        loaderByApkPath[apkPath] = classLoader

        val clazz = try {
            classLoader.loadClass(resolvedClassName)
        } catch (e: Throwable) {
            Log.e(TAG, "Failed to load class $resolvedClassName from APK", e)
            throw e
        }
        Log.d(TAG, "Loaded class: ${clazz.name} (classLoader=${clazz.classLoader})")

        // Dump interfaces for debugging
        val ifaces = clazz.interfaces.map { it.name }
        Log.d(TAG, "Class interfaces: $ifaces")
        val superclass = clazz.superclass
        Log.d(TAG, "Superclass: ${superclass?.name}")

        return instantiate(clazz, resolvedClassName)
    }

    fun unloadApk(apkPath: String) {
        Log.d(TAG, "unloadApk: $apkPath")
        loaderByApkPath.remove(apkPath)
    }

    fun isLoaded(apkPath: String): Boolean {
        val loaded = loaderByApkPath.containsKey(apkPath)
        Log.d(TAG, "isLoaded: $apkPath → $loaded")
        return loaded
    }

    fun loadedApkPaths(): Set<String> = loaderByApkPath.keys.toSet()

    /**
     * Mihon-style instantiation: uses `when` type matching instead of
     * `isAssignableFrom`, catches [Throwable] so linkage/verify errors
     * don't slip past.
     */
    private fun instantiate(clazz: Class<*>, tag: String): Source {
        val instance = try {
            clazz.getDeclaredConstructor().newInstance()
        } catch (e: Throwable) {
            Log.e(TAG, "Failed to instantiate $tag via no-arg constructor", e)
            throw e
        }
        Log.d(TAG, "Instantiated: ${instance.javaClass.name}")

        // Check using Kotlin `when` with proper is-checks (Mihon approach)
        return when (instance) {
            is SourceFactory -> {
                Log.d(TAG, "$tag is SourceFactory, calling createSources()")
                val sources = try {
                    instance.createSources()
                } catch (e: Throwable) {
                    Log.e(TAG, "createSources() threw for $tag", e)
                    throw e
                }
                if (sources.isEmpty()) {
                    val msg = "SourceFactory returned empty list for $tag"
                    Log.e(TAG, msg)
                    throw IllegalArgumentException(msg)
                }
                val first = sources.first()
                Log.d(TAG, "createSources() returned ${sources.size} sources, first=${first.javaClass.name} id=${first.id}")
                first
            }
            is Source -> {
                Log.d(TAG, "$tag is Source directly")
                instance
            }
            else -> {
                val msg = "Class $tag (${instance.javaClass.name}) is neither Source nor SourceFactory"
                Log.e(TAG, msg)
                Log.e(TAG, "  implements: ${clazz.interfaces.map { it.name }}")
                Log.e(TAG, "  superclass: ${clazz.superclass}")
                throw IllegalArgumentException(msg)
            }
        }
    }

    private fun enforceReadOnly(file: File?, label: String) {
        if (file == null) return
        try {
            file.setReadOnly()
        } catch (_: SecurityException) {
        }
    }
}
