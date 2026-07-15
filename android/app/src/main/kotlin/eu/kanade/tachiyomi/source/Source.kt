package eu.kanade.tachiyomi.source

/**
 * Minimal stand-in for `eu.kanade.tachiyomi.source.Source`.
 *
 * Real Keiyoushi/Mihon extensions implement this interface and the loader
 * looks up sources by `id`. We only declare the members that an extension
 * might call at load time — anything else can be added as the integration
 * grows.
 */
interface Source {

    /** Display name shown in the source picker (e.g. "MangaPill"). */
    val name: String

    /** Two-letter language code the source is in (e.g. "en"). */
    val lang: String

    /**
     * Stable numeric identifier for this source. Keiyoushi extensions
     * typically derive this from a hash of the source's class name so it
     * stays consistent across installs.
     */
    val id: Long
}
