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
                    else -> sendToWeb("ON_ERROR", JSONObject().apply {
                        put("message", "Hành động $action không hỗ trợ")
                    })
                }
            } catch (t: Throwable) {
                t.printStackTrace()
                sendToWeb("ON_ERROR", JSONObject().apply {
                    put("message", t.message ?: "Lỗi WebAppBridge")
                })
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
