package com.gamespace.ui

import android.annotation.SuppressLint
import android.os.Bundle
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.lifecycleScope
import com.gamespace.bridge.WebAppBridge
import com.gamespace.core.ShizukuManager

/**
 * Activity chính khởi tạo WebView và liên kết với ShizukuManager.
 */
class MainActivity : AppCompatActivity(), ShizukuManager.StateListener {

    private lateinit var webView: WebView
    private lateinit var webAppBridge: WebAppBridge

    @SuppressLint("SetJavaScriptEnabled")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        ShizukuManager.init()
        ShizukuManager.addListener(this)

        webView = WebView(this)
        setContentView(webView)

        webView.settings.apply {
            javaScriptEnabled = true
            domStorageEnabled = true
            allowFileAccess = true
            allowContentAccess = true
            cacheMode = WebSettings.LOAD_DEFAULT
        }

        webAppBridge = WebAppBridge(webView, lifecycleScope)
        webView.addJavascriptInterface(webAppBridge, "AndroidNativeBridge")

        webView.webViewClient = object : WebViewClient() {
            override fun onPageFinished(view: WebView?, url: String?) {
                super.onPageFinished(view, url)
                OnShizukuStateChanged(
                    ShizukuManager.isShizukuAvailable(),
                    ShizukuManager.hasShizukuPermission()
                )
            }
        }

        webView.loadUrl("file:///android_asset/index.html")
    }

    override fun OnShizukuStateChanged(isAvailable: Boolean, hasPermission: Boolean) {
        runOnUiThread {
            if (::webAppBridge.isInitialized) {
                webAppBridge.notifyShizukuState(isAvailable, hasPermission)
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        ShizukuManager.removeListener(this)
        ShizukuManager.destroy()
    }
}
