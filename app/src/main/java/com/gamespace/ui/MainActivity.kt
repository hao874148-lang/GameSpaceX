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

        try {
            ShizukuManager.init()
            ShizukuManager.addListener(this)
        } catch (t: Throwable) {
            t.printStackTrace()
        }

        webView.loadUrl("file:///android_asset/index.html")
    }

    override fun OnShizukuStateChanged(isAvailable: Boolean, hasPermission: Boolean) {
        runOnUiThread {
            try {
                if (::webAppBridge.isInitialized) {
                    webAppBridge.notifyShizukuState(isAvailable, hasPermission)
                }
            } catch (t: Throwable) {
                t.printStackTrace()
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        try {
            ShizukuManager.removeListener(this)
            ShizukuManager.destroy()
        } catch (t: Throwable) {
            t.printStackTrace()
        }
    }
}
