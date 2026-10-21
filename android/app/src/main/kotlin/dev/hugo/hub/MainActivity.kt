package dev.hugo.hub

import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.webviewflutter.WebViewFlutterAndroidExternalApi

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dev.hugo.hub/webview")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // Installs SpaceAssetClient on a webview_flutter WebView.
                    "enableSpaceAssetFix" -> {
                        val id = (call.arguments as Number).toLong()
                        val webView = WebViewFlutterAndroidExternalApi.getWebView(flutterEngine, id)
                        // WebView.getWebViewClient() needs Android 8.0+.
                        if (webView == null || Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
                            result.success(false)
                        } else {
                            val current = webView.webViewClient
                            if (current !is SpaceAssetClient) webView.webViewClient = SpaceAssetClient(current)
                            result.success(true)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
