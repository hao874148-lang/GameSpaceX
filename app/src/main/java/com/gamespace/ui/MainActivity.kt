package com.gamespace.ui

import android.annotation.SuppressLint
import android.os.Bundle
import android.webkit.WebChromeClient
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.lifecycleScope
import com.gamespace.bridge.WebAppBridge
import com.gamespace.core.ShizukuManager

class MainActivity : AppCompatActivity(), ShizukuManager.StateListener {

    private lateinit var webView: WebView
    private var webAppBridge: WebAppBridge? = null

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
            allowFileAccessFromFileURLs = true
            allowUniversalAccessFromFileURLs = true
            cacheMode = WebSettings.LOAD_NO_CACHE
        }

        webView.webChromeClient = WebChromeClient()

        val bridge = WebAppBridge(webView, lifecycleScope)
        webAppBridge = bridge
        webView.addJavascriptInterface(bridge, "AndroidNativeBridge")

        webView.webViewClient = object : WebViewClient() {
            override fun onPageFinished(view: WebView?, url: String?) {
                super.onPageFinished(view, url)
                notifyShizukuState()
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

    override fun onResume() {
        super.onResume()
        notifyShizukuState()
    }

    override fun OnShizukuStateChanged(isAvailable: Boolean, hasPermission: Boolean) {
        runOnUiThread {
            notifyShizukuState()
        }
    }

    private fun notifyShizukuState() {
        try {
            val available = ShizukuManager.isShizukuAvailable()
            val permitted = ShizukuManager.hasShizukuPermission()
            webAppBridge?.notifyShizukuState(available, permitted)
        } catch (t: Throwable) {
            t.printStackTrace()
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
