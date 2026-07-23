package com.koma.koma

import eu.kanade.tachiyomi.extension.KeiyoushiMethodChannel
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {

    private var keiyoushiChannel: KeiyoushiMethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Wire the Keiyoushi extension bridge. The channel handler is
        // stateless wrt Flutter engine lifecycle, so we re-create it on
        // every configure call to handle engine restart correctly.
        val channel = KeiyoushiMethodChannel(applicationContext)
        channel.registerOn(flutterEngine)
        keiyoushiChannel = channel
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        keiyoushiChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
