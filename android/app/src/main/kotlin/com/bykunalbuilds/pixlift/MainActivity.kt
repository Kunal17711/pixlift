package com.bykunalbuilds.pixlift

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Register the on-device ONNX bridge. Inference runs on a background
        // thread so the Flutter UI stays smooth.
        OnnxBridge(flutterEngine.dartExecutor.binaryMessenger)
    }
}
