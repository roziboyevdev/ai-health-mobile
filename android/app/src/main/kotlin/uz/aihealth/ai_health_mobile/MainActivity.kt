package uz.aihealth.ai_health_mobile

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class A : FlutterActivity() {
    private var blePlugin: HBandBlePlugin? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        blePlugin = HBandBlePlugin(this, flutterEngine.dartExecutor.binaryMessenger).also {
            it.register()
        }
    }

    override fun onDestroy() {
        blePlugin?.dispose()
        blePlugin = null
        super.onDestroy()
    }
}
