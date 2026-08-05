package com.koma.koma

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.util.TypedValue
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.appcompat.view.ContextThemeWrapper
import androidx.appcompat.widget.Toolbar
import androidx.core.view.ViewCompat
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.preference.DialogPreference
import androidx.preference.PreferenceFragmentCompat
import androidx.preference.PreferenceScreen
import androidx.preference.forEach
import eu.kanade.tachiyomi.data.preference.SharedPreferencesDataStore
import eu.kanade.tachiyomi.extension.DalvikRuntimeManager
import eu.kanade.tachiyomi.extension.DalvikServer
import eu.kanade.tachiyomi.source.ConfigurableSource
import eu.kanade.tachiyomi.source.sourcePreferences

/**
 * Mihon-faithful host for [ConfigurableSource.setupPreferenceScreen].
 * Opened from Flutter Extension Detail via MethodChannel.
 */
class SourcePreferencesActivity : AppCompatActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_source_preferences)

        // Edge-to-edge (targetSdk 35+) draws content under system bars; pad the root
        // so the toolbar sits below the status bar and prefs sit below the toolbar.
        WindowCompat.setDecorFitsSystemWindows(window, false)
        val root = findViewById<android.view.View>(R.id.source_prefs_root)
        ViewCompat.setOnApplyWindowInsetsListener(root) { view, insets ->
            val bars = insets.getInsets(WindowInsetsCompat.Type.systemBars())
            view.setPadding(bars.left, bars.top, bars.right, bars.bottom)
            insets
        }

        val sourceId = intent.getStringExtra(EXTRA_SOURCE_ID).orEmpty()
        val title = intent.getStringExtra(EXTRA_TITLE).orEmpty()
            .ifBlank { getString(R.string.source_settings_title) }

        val toolbar = findViewById<Toolbar>(R.id.toolbar)
        setSupportActionBar(toolbar)
        supportActionBar?.setDisplayHomeAsUpEnabled(true)
        supportActionBar?.title = title

        if (sourceId.isBlank()) {
            Toast.makeText(this, R.string.source_settings_missing, Toast.LENGTH_SHORT).show()
            finish()
            return
        }

        DalvikRuntimeManager.initialize(applicationContext)
        try {
            DalvikRuntimeManager.getOrStartServer()
        } catch (_: Throwable) {
            // Preferences only need a loaded extension; server start is best-effort.
        }

        val source = try {
            DalvikServer.getInstance().findHttpSource(sourceId)
        } catch (_: Throwable) {
            null
        }
        if (source !is ConfigurableSource) {
            Toast.makeText(this, R.string.source_settings_unavailable, Toast.LENGTH_SHORT).show()
            finish()
            return
        }

        if (savedInstanceState == null) {
            supportFragmentManager.beginTransaction()
                .replace(
                    R.id.prefs_container,
                    SourcePreferencesFragment.newInstance(sourceId),
                )
                .commit()
        }
    }

    override fun onSupportNavigateUp(): Boolean {
        finish()
        return true
    }

    companion object {
        const val EXTRA_SOURCE_ID = "source_id"
        const val EXTRA_TITLE = "title"

        fun intent(context: Context, sourceId: String, title: String?): Intent {
            return Intent(context, SourcePreferencesActivity::class.java).apply {
                putExtra(EXTRA_SOURCE_ID, sourceId)
                if (!title.isNullOrBlank()) putExtra(EXTRA_TITLE, title)
            }
        }
    }
}

class SourcePreferencesFragment : PreferenceFragmentCompat() {

    override fun getContext(): Context? {
        val superCtx = super.getContext() ?: return null
        val tv = TypedValue()
        // preferenceTheme lives on androidx.preference.R, not the app R.
        val hasTheme = superCtx.theme.resolveAttribute(
            androidx.preference.R.attr.preferenceTheme,
            tv,
            true,
        )
        return if (hasTheme && tv.resourceId != 0) {
            ContextThemeWrapper(superCtx, tv.resourceId)
        } else {
            ContextThemeWrapper(superCtx, androidx.preference.R.style.PreferenceThemeOverlay)
        }
    }

    override fun onCreatePreferences(savedInstanceState: Bundle?, rootKey: String?) {
        preferenceScreen = populateScreen()
    }

    private fun populateScreen(): PreferenceScreen {
        val sourceId = requireArguments().getString(ARG_SOURCE_ID).orEmpty()
        val sourceScreen = preferenceManager.createPreferenceScreen(requireContext())
        val source = try {
            DalvikServer.getInstance().findHttpSource(sourceId)
        } catch (_: Throwable) {
            null
        }
        if (source is ConfigurableSource) {
            preferenceManager.preferenceDataStore =
                SharedPreferencesDataStore(source.sourcePreferences())
            source.setupPreferenceScreen(sourceScreen)
            sourceScreen.forEach { pref ->
                pref.isIconSpaceReserved = false
                pref.isSingleLineTitle = false
                if (pref is DialogPreference && pref.dialogTitle.isNullOrEmpty()) {
                    pref.dialogTitle = pref.title
                }
            }
        }
        return sourceScreen
    }

    companion object {
        private const val ARG_SOURCE_ID = "source_id"

        fun newInstance(sourceId: String): SourcePreferencesFragment {
            return SourcePreferencesFragment().apply {
                arguments = Bundle().apply {
                    putString(ARG_SOURCE_ID, sourceId)
                }
            }
        }
    }
}
