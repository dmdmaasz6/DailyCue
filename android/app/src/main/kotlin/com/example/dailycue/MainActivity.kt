package com.example.dailycue

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var onnxPlugin: OnnxInferencePlugin? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        onnxPlugin = OnnxInferencePlugin(this, flutterEngine)
    }

    override fun onDestroy() {
        onnxPlugin?.dispose()
        super.onDestroy()
    }
}
