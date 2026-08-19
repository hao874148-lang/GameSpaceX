package com.gamespace.bridge

import android.webkit.WebView
import androidx.lifecycle.LifecycleCoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class WebAppBridge(
    private val webView: WebView,
    private val lifecycleScope: LifecycleCoroutineScope
) {
    @android.webkit.JavascriptInterface
    fun notifyShizukuState(available: Boolean, permitted: Boolean) {
        val availableJs = if (available) "true" else "false"
        val permittedJs = if (permitted) "true" else "false"
        val script = "if(window.onShizukuState) { window.onShizukuState($availableJs, $permittedJs); };"
        lifecycleScope.launch(Dispatchers.Main) {
            webView.evaluateJavascript(script, null)
        }
    }
}
