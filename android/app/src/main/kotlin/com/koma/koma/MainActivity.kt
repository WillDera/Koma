package com.koma.koma

import eu.kanade.tachiyomi.extension.DalvikServer
import eu.kanade.tachiyomi.extension.KeiyoushiEngine
import eu.kanade.tachiyomi.extension.KeiyoushiMethodChannel
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {

    private var keiyoushiChannel: KeiyoushiMethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val engine = KeiyoushiEngine(applicationContext)
        keiyoushiChannel = KeiyoushiMethodChannel(applicationContext, engine)
        keiyoushiChannel?.registerOn(flutterEngine)
        DalvikServer.getInstance().apply {
            this.engine = engine
            start()
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        keiyoushiChannel = null
        DalvikServer.getInstance().stop()
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
