package eu.kanade.tachiyomi.extension

import android.util.Log
import eu.kanade.tachiyomi.network.interceptor.BaseUrlHostRewrite
import eu.kanade.tachiyomi.source.online.HttpSource
import java.lang.reflect.Field
import java.lang.reflect.Modifier

private const val TAG = "HttpSourceBaseUrl"

/**
 * Apply Flutter's Source URL override to a loaded Mihon [HttpSource].
 *
 * 1. Mutate the APK's `baseUrl` field when possible (relative URL builders).
 * 2. Register an OkHttp host rewrite from [packagedBaseUrl] → override so
 *    hardcoded absolute URLs in the extension still hit the new domain.
 *
 * Returns true when the field was updated or a host rewrite was registered
 * (either is enough for browse/detail to use the new origin).
 */
fun applyHttpSourceBaseUrl(
    source: HttpSource,
    override: String,
    packagedBaseUrl: String = source.baseUrl,
): Boolean {
    val url = override.trim().trimEnd('/')
    if (url.isEmpty()) return false

    var fieldOk = source.baseUrl == url
    if (!fieldOk) {
        fieldOk = mutateBaseUrlField(source, url)
    }

    val packaged = packagedBaseUrl.trim().trimEnd('/').ifEmpty { source.baseUrl }
    if (packaged.isNotEmpty() && packaged != url) {
        BaseUrlHostRewrite.register(packaged, url)
    }

    Log.d(
        TAG,
        "override ${source.javaClass.simpleName}: fieldOk=$fieldOk " +
            "packaged=$packaged → $url (getter=${source.baseUrl})",
    )
    return fieldOk || packaged != url
}

private fun mutateBaseUrlField(source: HttpSource, url: String): Boolean {
    var cls: Class<*>? = source.javaClass
    while (cls != null && cls != Any::class.java) {
        if (cls == HttpSource::class.java) {
            cls = cls.superclass
            continue
        }
        try {
            val field = cls.getDeclaredField("baseUrl")
            if (!writeBaseUrlField(field, source, url)) {
                Log.w(TAG, "could not write baseUrl on ${cls.name}")
                return false
            }
            val readBack = runCatching { field.get(source) as? String }.getOrNull()
            if (readBack == url || source.baseUrl == url) return true
            Log.w(TAG, "baseUrl write did not stick on ${cls.name} (got $readBack)")
            return false
        } catch (_: NoSuchFieldException) {
            cls = cls.superclass
        } catch (e: Throwable) {
            Log.w(TAG, "baseUrl override failed on ${cls?.name}", e)
            return false
        }
    }
    Log.w(TAG, "no baseUrl field on ${source.javaClass.name}")
    return false
}

private fun writeBaseUrlField(field: Field, target: Any, value: String): Boolean {
    field.isAccessible = true
    if (Modifier.isFinal(field.modifiers)) {
        try {
            val mods = Field::class.java.getDeclaredField("modifiers")
            mods.isAccessible = true
            mods.setInt(field, field.modifiers and Modifier.FINAL.inv())
        } catch (_: Throwable) {
            // Android may block modifiers — try set() anyway.
        }
    }
    return try {
        field.set(target, value)
        true
    } catch (e: Throwable) {
        Log.w(TAG, "Field.set(baseUrl) failed", e)
        false
    }
}
