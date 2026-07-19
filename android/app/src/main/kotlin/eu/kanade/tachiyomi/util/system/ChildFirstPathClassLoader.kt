package eu.kanade.tachiyomi.util.system

import dalvik.system.PathClassLoader

/**
 * Parent-last classloader matching Mihon's approach.
 * Order: system → child (APK) → parent (app).
 */
class ChildFirstPathClassLoader(
    dexPath: String,
    librarySearchPath: String?,
    parent: ClassLoader,
) : PathClassLoader(dexPath, librarySearchPath, parent) {

    override fun loadClass(name: String?, resolve: Boolean): Class<*> {
        var c = findLoadedClass(name)

        if (c == null) {
            if (name != null && name.startsWith("uy.kohesive.injekt.")) {
                // Injekt must come from the host app so our Injekt.importModule
                // registrations (Application, OkHttpClient, NetworkHelper, etc.)
                // are visible to extension code.
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
}
