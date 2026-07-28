package com.koma.koma

import eu.kanade.tachiyomi.extension.DalvikServer
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {

    private var dalvikServer: DalvikServer? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        dalvikServer = DalvikServer()
        dalvikServer?.start()
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        dalvikServer?.stop()
        dalvikServer = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
