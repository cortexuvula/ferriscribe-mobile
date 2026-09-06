package com.ferriscribe.ferriscribe_mobile

import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Block screenshots, screen recording, and app-switcher content
        // capture (PHI). This is Android's equivalent of the iOS capture mask.
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.ferriscribe.mobile/native")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // Backup is disabled app-wide via the manifest
                    // (allowBackup=false + data-extraction rules), so this is
                    // a no-op success on Android.
                    "excludeFromBackup" -> result.success(true)
                    else -> result.notImplemented()
                }
            }
    }
}
