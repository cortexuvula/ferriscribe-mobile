package ai.ferriscribe.mobile

import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity (NOT FlutterActivity): local_auth 3.x
// requires a FragmentActivity host for BiometricPrompt — with the
// plain activity, authenticate() throws PlatformException and the
// unlock button does nothing (user report on #46).
class MainActivity : FlutterFragmentActivity() {
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
