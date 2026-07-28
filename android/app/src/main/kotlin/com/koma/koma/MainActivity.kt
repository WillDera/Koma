package com.koma.koma

import eu.kanade.tachiyomi.extension.DalvikServer
import eu.kanade.tachiyomi.extension.KeiyoushiEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val engine = KeiyoushiEngine(applicationContext)
        DalvikServer.getInstance().apply {
            this.engine = engine
            start()
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "eu.kanade.tachiyomi/keiyoushi",
        ).setMethodCallHandler { call, result ->
            if (call.method == "getDalvikPort") {
                val port = DalvikServer.getInstance().port
                if (port > 0) result.success(port)
                else result.error("NOSERVER", "Dalvik server not running", null)
            } else {
                result.notImplemented()
            }
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        DalvikServer.getInstance().stop()
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
