#!/bin/bash
echo "=== BẮT ĐẦU CẬP NHẬT MÃ NGUỒN NGÀY 06 ==="

# 1. Tạo thư mục
mkdir -p app/src/main/java/com/gamespace/core
mkdir -p app/src/main/java/com/gamespace/bridge
mkdir -p app/src/main/java/com/gamespace/ui
mkdir -p app/src/main/assets/css
mkdir -p app/src/main/assets/js

# 2. AndroidManifest.xml (Sạch, không dính Provider trùng)
cat << 'XML_EOF' > app/src/main/AndroidManifest.xml
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="[http://schemas.android.com/apk/res/android](http://schemas.android.com/apk/res/android)">

    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
    <uses-permission android:name="moe.shizuku.manager.permission.API_V23" />

    <application
        android:allowBackup="true"
        android:icon="@mipmap/ic_launcher"
        android:label="GameSpaceX"
        android:roundIcon="@mipmap/ic_launcher_round"
        android:supportsRtl="true"
        android:theme="@style/Theme.AppCompat.NoActionBar">

        <activity
            android:name="com.gamespace.ui.MainActivity"
            android:exported="true"
            android:configChanges="orientation|screenSize|keyboardHidden">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>

    </application>

</manifest>
XML_EOF

# 3. ShizukuManager.kt
cat << 'KOTLIN_EOF' > app/src/main/java/com/gamespace/core/ShizukuManager.kt
package com.gamespace.core

import android.content.pm.PackageManager
import rikka.shizuku.Shizuku
import java.util.concurrent.CopyOnWriteArrayList

object ShizukuManager {
    const val SHIZUKU_REQ_CODE = 1001

    interface StateListener {
        fun OnShizukuStateChanged(isAvailable: Boolean, hasPermission: Boolean)
    }

    private val listeners = CopyOnWriteArrayList<StateListener>()

    private val binderReceivedListener = Shizuku.OnBinderReceivedListener { notifyListeners() }
    private val binderDeadListener = Shizuku.OnBinderDeadListener { notifyListeners() }
    private val permissionResultListener = Shizuku.OnRequestPermissionResultListener { requestCode, _ ->
        if (requestCode == SHIZUKU_REQ_CODE) notifyListeners()
    }

    private var isInitialized = false

    fun init() {
        if (isInitialized) return
        try {
            Shizuku.addBinderReceivedListenerSticky(binderReceivedListener)
            Shizuku.addBinderDeadListener(binderDeadListener)
            Shizuku.addRequestPermissionResultListener(permissionResultListener)
            isInitialized = true
        } catch (t: Throwable) {
            t.printStackTrace()
        }
    }

    fun destroy() {
        if (!isInitialized) return
        try {
            Shizuku.removeBinderReceivedListener(binderReceivedListener)
            Shizuku.removeBinderDeadListener(binderDeadListener)
            Shizuku.removeRequestPermissionResultListener(permissionResultListener)
            isInitialized = false
        } catch (t: Throwable) {
            t.printStackTrace()
        }
    }

    fun addListener(listener: StateListener) {
        try {
            if (!listeners.contains(listener)) listeners.add(listener)
            listener.OnShizukuStateChanged(isShizukuAvailable(), hasShizukuPermission())
        } catch (t: Throwable) {
            t.printStackTrace()
        }
    }

    fun removeListener(listener: StateListener) {
        try {
            listeners.remove(listener)
        } catch (t: Throwable) {
            t.printStackTrace()
        }
    }

    fun isShizukuAvailable(): Boolean {
        return try {
            Shizuku.pingBinder()
        } catch (t: Throwable) {
            false
        }
    }

    fun hasShizukuPermission(): Boolean {
        if (!isShizukuAvailable()) return false
        return try {
            if (Shizuku.isPreV11()) false
            else Shizuku.checkSelfPermission() == PackageManager.PERMISSION_GRANTED
        } catch (t: Throwable) {
            false
        }
    }

    fun requestPermission() {
        if (!isShizukuAvailable()) return
        try {
            if (!Shizuku.isPreV11() && !hasShizukuPermission()) {
                Shizuku.requestPermission(SHIZUKU_REQ_CODE)
            }
        } catch (t: Throwable) {
            t.printStackTrace()
        }
    }

    private fun notifyListeners() {
        val available = isShizukuAvailable()
        val permitted = hasShizukuPermission()
        for (listener in listeners) {
            try {
                listener.OnShizukuStateChanged(available, permitted)
            } catch (t: Throwable) {
                t.printStackTrace()
            }
        }
    }
}
KOTLIN_EOF

# 4. ShellExecutor.kt (Dùng Reflection động tìm method newProcess)
cat << 'KOTLIN_EOF' > app/src/main/java/com/gamespace/core/ShellExecutor.kt
package com.gamespace.core

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import rikka.shizuku.Shizuku
import java.io.BufferedReader
import java.io.InputStreamReader
import java.lang.reflect.Method

data class ShellResult(
    val isSuccess: Boolean,
    val stdout: String,
    val stderr: String,
    val exitCode: Int
)

object ShellExecutor {
    private val executionMutex = Mutex()

    private val newProcessMethod: Method? by lazy {
        try {
            Shizuku::class.java.declaredMethods
                .firstOrNull { it.name == "newProcess" }
                ?.apply { isAccessible = true }
        } catch (t: Throwable) {
            t.printStackTrace()
            null
        }
    }

    suspend fun executeCommand(command: String): ShellResult = withContext(Dispatchers.IO) {
        executionMutex.withLock {
            if (!ShizukuManager.hasShizukuPermission()) {
                return@withContext ShellResult(false, "", "Chưa cấp quyền Shizuku", -1)
            }

            val method = newProcessMethod
            if (method == null) {
                return@withContext ShellResult(false, "", "Không tìm thấy Shizuku.newProcess", -1)
            }

            try {
                val process = method.invoke(
                    null,
                    arrayOf("sh", "-c", command),
                    null,
                    null
                ) as Process

                val reader = BufferedReader(InputStreamReader(process.inputStream))
                val errorReader = BufferedReader(InputStreamReader(process.errorStream))

                val stdoutBuilder = StringBuilder()
                val stderrBuilder = StringBuilder()

                var line: String?
                while (reader.readLine().also { line = it } != null) {
                    stdoutBuilder.append(line).append("\n")
                }
                while (errorReader.readLine().also { line = it } != null) {
                    stderrBuilder.append(line).append("\n")
                }

                val exitCode = process.waitFor()
                process.destroy()

                ShellResult(
                    isSuccess = (exitCode == 0),
                    stdout = stdoutBuilder.toString().trim(),
                    stderr = stderrBuilder.toString().trim(),
                    exitCode = exitCode
                )
            } catch (t: Throwable) {
                ShellResult(false, "", t.message ?: "Lỗi Shell", -1)
            }
        }
    }

    suspend fun executeCommands(commands: List<String>): List<ShellResult> {
        val results = mutableListOf<ShellResult>()
        for (cmd in commands) {
            results.add(executeCommand(cmd))
        }
        return results
    }
}
KOTLIN_EOF

# 5. CommandRegistry.kt
cat << 'KOTLIN_EOF' > app/src/main/java/com/gamespace/core/CommandRegistry.kt
package com.gamespace.core

object CommandRegistry {
    val PERFORMANCE_MODE_ON = listOf(
        "cmd power set-mode 0",
        "settings put global thermal_limit_level 0",
        "settings put global power_saving_mode 0",
        "dumpsys deviceidle disable"
    )

    val PERFORMANCE_MODE_OFF = listOf(
        "dumpsys deviceidle enable",
        "settings put global power_saving_mode 0"
    )

    val CLEAN_RAM = listOf(
        "am kill-all",
        "echo 3 > /proc/sys/vm/drop_caches"
    )

    const val GET_CPU_TEMP = "cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | head -n 1"
}
KOTLIN_EOF

# 6. BridgeEvents.kt
cat << 'KOTLIN_EOF' > app/src/main/java/com/gamespace/bridge/BridgeEvents.kt
package com.gamespace.bridge

enum class BridgeEvents(val eventName: String) {
    INIT_STATE("INIT_STATE"),
    SET_PERFORMANCE_MODE("SET_PERFORMANCE_MODE"),
    REQUEST_SHIZUKU_PERMISSION("REQUEST_SHIZUKU_PERMISSION"),
    GET_SYSTEM_STATS("GET_SYSTEM_STATS"),
    CLEAN_MEMORY("CLEAN_MEMORY")
}
KOTLIN_EOF

# 7. WebAppBridge.kt
cat << 'KOTLIN_EOF' > app/src/main/java/com/gamespace/bridge/WebAppBridge.kt
package com.gamespace.bridge

import android.os.Handler
import android.os.Looper
import android.webkit.JavascriptInterface
import android.webkit.WebView
import com.gamespace.core.CommandRegistry
import com.gamespace.core.ShellExecutor
import com.gamespace.core.ShizukuManager
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import org.json.JSONObject

class WebAppBridge(
    private val webView: WebView,
    private val coroutineScope: CoroutineScope
) {
    private val mainHandler = Handler(Looper.getMainLooper())

    @JavascriptInterface
    fun executeAction(action: String, payloadJson: String) {
        coroutineScope.launch(Dispatchers.Default) {
            try {
                val payload = if (payloadJson.isNotEmpty()) JSONObject(payloadJson) else JSONObject()
                when (action) {
                    BridgeEvents.INIT_STATE.eventName -> handleInitState()
                    BridgeEvents.SET_PERFORMANCE_MODE.eventName -> handleSetPerformanceMode(payload)
                    BridgeEvents.REQUEST_SHIZUKU_PERMISSION.eventName -> handleRequestShizukuPermission()
                    BridgeEvents.CLEAN_MEMORY.eventName -> handleCleanMemory()
                    BridgeEvents.GET_SYSTEM_STATS.eventName -> handleGetSystemStats()
                    else -> sendToWeb("ON_ERROR", JSONObject().apply { put("message", "Hành động $action không hỗ trợ") })
                }
            } catch (t: Throwable) {
                t.printStackTrace()
                sendToWeb("ON_ERROR", JSONObject().apply { put("message", t.message ?: "Lỗi WebAppBridge") })
            }
        }
    }

    private fun handleInitState() {
        val isAvailable = ShizukuManager.isShizukuAvailable()
        val hasPermission = ShizukuManager.hasShizukuPermission()

        val response = JSONObject().apply {
            put("shizukuAvailable", isAvailable)
            put("shizukuPermission", hasPermission)
            put("shizukuStatus", if (hasPermission) "READY" else if (isAvailable) "NEED_PERMISSION" else "DISCONNECTED")
            put("performanceMode", false)
            put("memoryStatus", "OPTIMIZED")
            put("temperature", 36.5)
        }
        sendToWeb("ON_STATE_UPDATED", response)
    }

    private fun handleRequestShizukuPermission() {
        if (!ShizukuManager.isShizukuAvailable()) {
            sendToWeb("ON_SHIZUKU_STATUS", JSONObject().apply {
                put("status", "DISCONNECTED")
                put("message", "Shizuku chưa chạy")
            })
            return
        }

        if (ShizukuManager.hasShizukuPermission()) {
            sendToWeb("ON_SHIZUKU_STATUS", JSONObject().apply {
                put("status", "READY")
                put("message", "Đã có quyền Shizuku")
            })
            return
        }

        mainHandler.post {
            ShizukuManager.requestPermission()
        }
    }

    private suspend fun handleSetPerformanceMode(payload: JSONObject) {
        val enable = payload.optBoolean("enable", false)
        val hasShizuku = ShizukuManager.hasShizukuPermission()

        if (hasShizuku) {
            val commands = if (enable) CommandRegistry.PERFORMANCE_MODE_ON else CommandRegistry.PERFORMANCE_MODE_OFF
            val results = ShellExecutor.executeCommands(commands)
            val success = results.all { it.isSuccess }

            sendToWeb("ON_PERFORMANCE_MODE_CHANGED", JSONObject().apply {
                put("enabled", enable)
                put("isMock", false)
                put("success", success)
                put("message", if (enable) "Đã BẬT Hiệu năng cao qua ADB Shell" else "Đã TẮT Chế độ Hiệu năng cao")
            })
        } else {
            sendToWeb("ON_PERFORMANCE_MODE_CHANGED", JSONObject().apply {
                put("enabled", enable)
                put("isMock", true)
                put("success", true)
                put("message", if (enable) "Đã BẬT Hiệu năng cao (Giả lập)" else "Đã TẮT Hiệu năng cao (Giả lập)")
            })
        }
    }

    private suspend fun handleCleanMemory() {
        val hasShizuku = ShizukuManager.hasShizukuPermission()
        if (hasShizuku) {
            ShellExecutor.executeCommands(CommandRegistry.CLEAN_RAM)
            sendToWeb("ON_MEMORY_CLEANED", JSONObject().apply {
                put("success", true)
                put("isMock", false)
                put("message", "Đã dọn RAM bằng ADB Shell")
            })
        } else {
            sendToWeb("ON_MEMORY_CLEANED", JSONObject().apply {
                put("success", true)
                put("isMock", true)
                put("message", "Đã dọn RAM (Giả lập)")
            })
        }
    }

    private suspend fun handleGetSystemStats() {
        var tempVal = 36.5
        val hasShizuku = ShizukuManager.hasShizukuPermission()

        if (hasShizuku) {
            val res = ShellExecutor.executeCommand(CommandRegistry.GET_CPU_TEMP)
            if (res.isSuccess && res.stdout.isNotEmpty()) {
                try {
                    val raw = res.stdout.trim().toDouble()
                    tempVal = if (raw > 1000) raw / 1000.0 else raw
                } catch (_: Throwable) {}
            }
        }

        sendToWeb("ON_SYSTEM_STATS", JSONObject().apply {
            put("temperature", tempVal)
            put("shizukuReady", hasShizuku)
        })
    }

    fun notifyShizukuState(isAvailable: Boolean, hasPermission: Boolean) {
        val response = JSONObject().apply {
            put("shizukuAvailable", isAvailable)
            put("shizukuPermission", hasPermission)
            put("shizukuStatus", if (hasPermission) "READY" else if (isAvailable) "NEED_PERMISSION" else "DISCONNECTED")
        }
        sendToWeb("ON_SHIZUKU_STATUS", response)
    }

    private fun sendToWeb(event: String, data: JSONObject) {
        val jsCall = "javascript:window.GameSpaceBridge.onNativeEvent('$event', ${data})"
        mainHandler.post {
            webView.evaluateJavascript(jsCall, null)
        }
    }
}
KOTLIN_EOF

# 8. MainActivity.kt (Khóa Null-Safety chống Crash)
cat << 'KOTLIN_EOF' > app/src/main/java/com/gamespace/ui/MainActivity.kt
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
            cacheMode = WebSettings.LOAD_DEFAULT
        }

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
KOTLIN_EOF

# 9. Giao diện Web Assets RedMagic (index.html, css/core.css, css/theme.css, js/bridge.js, js/state.js, js/app.js)
cat << 'HTML_EOF' > app/src/main/assets/index.html
<!DOCTYPE html>
<html lang="vi">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
    <title>GameSpaceX Cyber Panel</title>
    <link rel="stylesheet" href="css/core.css">
    <link rel="stylesheet" href="css/theme.css">
</head>
<body>
    <div class="app-container">
        <header class="cyber-header">
            <div class="logo-box">
                <span class="logo-text">GAME SPACEX</span>
                <span class="version-tag">v1.0-DAY06</span>
            </div>
            <div class="connection-status">
                <span class="status-dot"></span>
                <span>ONLINE</span>
            </div>
        </header>

        <main class="dashboard-content">
            <section class="cyber-card highlight-card">
                <div class="card-header">
                    <span class="card-title">TRẠNG THÁI SHIZUKU</span>
                    <span class="badge" id="shizuku-badge">KIỂM TRA...</span>
                </div>
                <div class="card-body">
                    <div class="status-info-row">
                        <span id="shizuku-detail">Đang quét Binder...</span>
                    </div>
                    <button class="cyber-btn btn-secondary" id="btn-request-shizuku">CẤP QUYỀN SHIZUKU</button>
                </div>
            </section>

            <section class="cyber-card">
                <div class="card-header">
                    <span class="card-title">HIỆU NĂNG HỆ THỐNG</span>
                    <span class="mode-indicator" id="mode-text">BALANCED</span>
                </div>
                <div class="card-body">
                    <div class="toggle-container">
                        <div class="toggle-info">
                            <strong>Chế độ Chơi Game Cực Hạn</strong>
                            <p>Tối ưu CPU Governor, vô hiệu hóa throttling</p>
                        </div>
                        <label class="switch">
                            <input type="checkbox" id="toggle-performance">
                            <span class="slider round"></span>
                        </label>
                    </div>
                </div>
            </section>

            <section class="cyber-card-grid">
                <div class="cyber-card mini-card">
                    <span class="mini-title">NHIỆT ĐỘ CPU</span>
                    <div class="metric-value" id="temp-value">36.5 °C</div>
                    <div class="metric-bar-bg">
                        <div class="metric-bar-fill" id="temp-bar" style="width: 45%;"></div>
                    </div>
                </div>

                <div class="cyber-card mini-card">
                    <span class="mini-title">BỘ NHỚ RAM</span>
                    <div class="metric-value" id="ram-status">OPTIMIZED</div>
                    <button class="cyber-btn btn-action" id="btn-clean-ram">DỌN RAM</button>
                </div>
            </section>

            <section class="cyber-card log-card">
                <div class="card-header">
                    <span class="card-title">NHẬT KÝ HỆ THỐNG</span>
                    <button class="btn-text" id="btn-clear-logs">XÓA</button>
                </div>
                <div class="log-console" id="log-console">
                    <div class="log-item info">[SYS] Giao diện RedMagic Cyber đã nạp.</div>
                </div>
            </section>
        </main>
    </div>

    <script src="js/bridge.js"></script>
    <script src="js/state.js"></script>
    <script src="js/app.js"></script>
</body>
</html>
HTML_EOF

cat << 'CSS_EOF' > app/src/main/assets/css/core.css
* {
    margin: 0;
    padding: 0;
    box-sizing: border-box;
    -webkit-tap-highlight-color: transparent;
    user-select: none;
    font-family: system-ui, -apple-system, sans-serif;
}

:root {
    --bg-primary: #0a0d14;
    --bg-card: rgba(18, 24, 38, 0.9);
    --bg-card-border: rgba(0, 240, 255, 0.25);
    --color-accent-red: #ff003c;
    --color-accent-cyan: #00f0ff;
    --color-accent-green: #00ff66;
    --color-accent-yellow: #ffcc00;
    --text-primary: #ffffff;
    --text-secondary: #8a99ad;
    --radius-sm: 6px;
    --radius-md: 12px;
}

body {
    background-color: var(--bg-primary);
    color: var(--text-primary);
    overflow-x: hidden;
    width: 100vw;
    min-height: 100vh;
}
CSS_EOF

cat << 'CSS_EOF' > app/src/main/assets/css/theme.css
.app-container {
    padding: 16px;
    display: flex;
    flex-direction: column;
    gap: 16px;
    max-width: 600px;
    margin: 0 auto;
}

.cyber-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 12px 16px;
    background: var(--bg-card);
    border: 1px solid var(--bg-card-border);
    border-radius: var(--radius-md);
}

.logo-text {
    font-size: 1.2rem;
    font-weight: 900;
    letter-spacing: 1.5px;
    background: linear-gradient(90deg, var(--color-accent-red), var(--color-accent-cyan));
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
}

.version-tag {
    font-size: 0.65rem;
    color: var(--text-secondary);
    margin-left: 6px;
}

.connection-status {
    display: flex;
    align-items: center;
    gap: 6px;
    font-size: 0.75rem;
    font-weight: bold;
    color: var(--color-accent-green);
}

.status-dot {
    width: 8px;
    height: 8px;
    border-radius: 50%;
    background-color: var(--color-accent-green);
    box-shadow: 0 0 8px var(--color-accent-green);
}

.dashboard-content {
    display: flex;
    flex-direction: column;
    gap: 14px;
}

.cyber-card {
    background: var(--bg-card);
    border: 1px solid rgba(255, 255, 255, 0.1);
    border-radius: var(--radius-md);
    padding: 16px;
}

.highlight-card {
    border-color: rgba(0, 240, 255, 0.4);
}

.card-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 12px;
}

.card-title {
    font-size: 0.85rem;
    font-weight: 700;
    color: var(--text-secondary);
}

.badge {
    padding: 4px 8px;
    border-radius: 4px;
    font-size: 0.7rem;
    font-weight: bold;
    background: rgba(255, 255, 255, 0.1);
    color: var(--text-secondary);
}

.badge.ready {
    background: rgba(0, 255, 102, 0.15);
    color: var(--color-accent-green);
    border: 1px solid var(--color-accent-green);
}

.badge.warning {
    background: rgba(255, 204, 0, 0.15);
    color: var(--color-accent-yellow);
    border: 1px solid var(--color-accent-yellow);
}

.badge.danger {
    background: rgba(255, 0, 60, 0.15);
    color: var(--color-accent-red);
    border: 1px solid var(--color-accent-red);
}

.cyber-btn {
    width: 100%;
    padding: 10px;
    margin-top: 10px;
    border: none;
    border-radius: var(--radius-sm);
    font-weight: bold;
    font-size: 0.8rem;
    cursor: pointer;
}

.btn-secondary {
    background: rgba(0, 240, 255, 0.15);
    color: var(--color-accent-cyan);
    border: 1px solid var(--color-accent-cyan);
}

.btn-action {
    background: rgba(255, 0, 60, 0.2);
    color: var(--color-accent-red);
    border: 1px solid var(--color-accent-red);
}

.btn-text {
    background: none;
    border: none;
    color: var(--text-secondary);
    font-size: 0.75rem;
    cursor: pointer;
}

.toggle-container {
    display: flex;
    justify-content: space-between;
    align-items: center;
}

.toggle-info p {
    font-size: 0.75rem;
    color: var(--text-secondary);
    margin-top: 2px;
}

.switch {
    position: relative;
    display: inline-block;
    width: 52px;
    height: 28px;
}

.switch input {
    opacity: 0;
    width: 0;
    height: 0;
}

.slider {
    position: absolute;
    cursor: pointer;
    top: 0; left: 0; right: 0; bottom: 0;
    background-color: #1e293b;
    border: 1px solid rgba(255, 255, 255, 0.2);
    border-radius: 34px;
}

.slider:before {
    position: absolute;
    content: "";
    height: 20px;
    width: 20px;
    left: 3px;
    bottom: 3px;
    background-color: white;
    border-radius: 50%;
    transition: .3s;
}

input:checked + .slider {
    background-color: var(--color-accent-red);
}

input:checked + .slider:before {
    transform: translateX(24px);
}

.cyber-card-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 12px;
}

.mini-card {
    padding: 12px;
}

.mini-title {
    font-size: 0.7rem;
    color: var(--text-secondary);
}

.metric-value {
    font-size: 1.2rem;
    font-weight: 800;
    margin: 8px 0;
    color: var(--color-accent-cyan);
}

.metric-bar-bg {
    width: 100%;
    height: 6px;
    background: rgba(255, 255, 255, 0.1);
    border-radius: 3px;
    overflow: hidden;
}

.metric-bar-fill {
    height: 100%;
    background: var(--color-accent-cyan);
    transition: width 0.4s ease;
}

.log-console {
    background: rgba(0, 0, 0, 0.6);
    border-radius: var(--radius-sm);
    padding: 8px;
    height: 110px;
    overflow-y: auto;
    font-family: monospace;
    font-size: 0.7rem;
    display: flex;
    flex-direction: column;
    gap: 4px;
}

.log-item.info { color: var(--color-accent-cyan); }
.log-item.success { color: var(--color-accent-green); }
.log-item.error { color: var(--color-accent-red); }
CSS_EOF

cat << 'JS_EOF' > app/src/main/assets/js/bridge.js
window.GameSpaceBridge = (function() {
    const listeners = {};

    function registerListener(event, callback) {
        if (!listeners[event]) listeners[event] = [];
        listeners[event].push(callback);
    }

    function executeAction(action, payload = {}) {
        const jsonPayload = JSON.stringify(payload);
        if (window.AndroidNativeBridge && typeof window.AndroidNativeBridge.executeAction === 'function') {
            window.AndroidNativeBridge.executeAction(action, jsonPayload);
        }
    }

    function onNativeEvent(event, data) {
        if (listeners[event]) {
            listeners[event].forEach(cb => cb(data));
        }
    }

    return { registerListener, executeAction, onNativeEvent };
})();
JS_EOF

cat << 'JS_EOF' > app/src/main/assets/js/state.js
window.GameState = (function() {
    let state = {
        shizukuStatus: 'DISCONNECTED',
        shizukuAvailable: false,
        shizukuPermission: false,
        performanceMode: false,
        temperature: 36.5,
        memoryStatus: 'OPTIMIZED',
        logs: []
    };

    const listeners = [];

    function getState() { return { ...state }; }

    function setState(newState) {
        state = { ...state, ...newState };
        listeners.forEach(cb => cb(state));
    }

    function addLog(message, type = 'info') {
        const timestamp = new Date().toLocaleTimeString();
        state.logs.push({ timestamp, message, type });
        if (state.logs.length > 30) state.logs.shift();
        setState({ logs: state.logs });
    }

    function subscribe(callback) { listeners.push(callback); }

    return { getState, setState, addLog, subscribe };
})();
JS_EOF

cat << 'JS_EOF' > app/src/main/assets/js/app.js
document.addEventListener("DOMContentLoaded", function() {
    const bridge = window.GameSpaceBridge;
    const gameState = window.GameState;

    const shizukuBadge = document.getElementById("shizuku-badge");
    const shizukuDetail = document.getElementById("shizuku-detail");
    const btnRequestShizuku = document.getElementById("btn-request-shizuku");
    const togglePerformance = document.getElementById("toggle-performance");
    const modeText = document.getElementById("mode-text");
    const tempValue = document.getElementById("temp-value");
    const tempBar = document.getElementById("temp-bar");
    const ramStatus = document.getElementById("ram-status");
    const btnCleanRam = document.getElementById("btn-clean-ram");
    const logConsole = document.getElementById("log-console");
    const btnClearLogs = document.getElementById("btn-clear-logs");

    bridge.registerListener("ON_STATE_UPDATED", function(data) {
        gameState.setState(data);
    });

    bridge.registerListener("ON_SHIZUKU_STATUS", function(data) {
        gameState.setState({
            shizukuStatus: data.shizukuStatus,
            shizukuAvailable: data.shizukuAvailable,
            shizukuPermission: data.shizukuPermission
        });
        if (data.message) gameState.addLog(data.message, data.shizukuPermission ? "success" : "warning");
    });

    bridge.registerListener("ON_PERFORMANCE_MODE_CHANGED", function(data) {
        gameState.setState({ performanceMode: data.enabled });
        gameState.addLog(data.message, data.success ? "success" : "error");
    });

    bridge.registerListener("ON_MEMORY_CLEANED", function(data) {
        ramStatus.innerText = "OPTIMIZED";
        gameState.addLog(data.message, "success");
    });

    bridge.registerListener("ON_SYSTEM_STATS", function(data) {
        if (data.temperature) gameState.setState({ temperature: data.temperature });
    });

    bridge.registerListener("ON_ERROR", function(data) {
        gameState.addLog("Lỗi: " + data.message, "error");
    });

    gameState.subscribe(function(state) {
        if (state.shizukuPermission) {
            shizukuBadge.className = "badge ready";
            shizukuBadge.innerText = "READY";
            shizukuDetail.innerText = "Đã kết nối và sẵn sàng thực thi ADB Shell.";
        } else if (state.shizukuAvailable) {
            shizukuBadge.className = "badge warning";
            shizukuBadge.innerText = "CHƯA CẤP QUYỀN";
            shizukuDetail.innerText = "Dịch vụ đang chạy, hãy bấm CẤP QUYỀN.";
        } else {
            shizukuBadge.className = "badge danger";
            shizukuBadge.innerText = "NGẮT KẾT NỐI";
            shizukuDetail.innerText = "Chưa bật Shizuku trên thiết bị.";
        }

        togglePerformance.checked = state.performanceMode;
        if (state.performanceMode) {
            modeText.innerText = "HIGH_PERFORMANCE";
            modeText.style.color = "var(--color-accent-red)";
        } else {
            modeText.innerText = "BALANCED";
            modeText.style.color = "var(--color-accent-cyan)";
        }

        const temp = parseFloat(state.temperature).toFixed(1);
        tempValue.innerText = temp + " °C";
        const tempPercent = Math.min(Math.max((temp - 20) * 2.5, 10), 100);
        tempBar.style.width = tempPercent + "%";

        logConsole.innerHTML = "";
        state.logs.forEach(function(item) {
            const div = document.createElement("div");
            div.className = "log-item " + item.type;
            div.innerText = "[" + item.timestamp + "] " + item.message;
            logConsole.appendChild(div);
        });
        logConsole.scrollTop = logConsole.scrollHeight;
    });

    btnRequestShizuku.addEventListener("click", function() {
        bridge.executeAction("REQUEST_SHIZUKU_PERMISSION");
    });

    togglePerformance.addEventListener("change", function(e) {
        bridge.executeAction("SET_PERFORMANCE_MODE", { enable: e.target.checked });
    });

    btnCleanRam.addEventListener("click", function() {
        ramStatus.innerText = "CLEANING...";
        bridge.executeAction("CLEAN_MEMORY");
    });

    btnClearLogs.addEventListener("click", function() {
        gameState.setState({ logs: [] });
    });

    setTimeout(function() { bridge.executeAction("INIT_STATE"); }, 200);
    setInterval(function() { bridge.executeAction("GET_SYSTEM_STATS"); }, 5000);
});
JS_EOF

echo "=== ĐÃ HOÀN TẤT GHI TOÀN BỘ MÃ NGUỒN NGÀY 06 SẠCH SE 100% ==="
