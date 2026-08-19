package com.gamespace.bridge

import android.os.Handler
import android.os.Looper
import android.webkit.JavascriptInterface
import android.webkit.WebView
import org.json.JSONObject
import java.lang.ref.WeakReference

/**
 * Cầu nối chính giữa WebView JavaScript và Native Kotlin code
 */
class WebAppBridge(webView: WebView) {

    private val webViewRef = WeakReference(webView)
    private val mainHandler = Handler(Looper.getMainLooper())

    @JavascriptInterface
    fun postMessage(jsonString: String) {
        try {
            val request = BridgeRequest.parse(jsonString)
            handleRequest(request)
        } catch (e: Exception) {
            val errorResponse = BridgeResponse(
                requestId = "error",
                action = "ERROR",
                success = false,
                message = "Lỗi xử lý JSON: ${e.localizedMessage}"
            )
            sendResponseToWeb(errorResponse)
        }
    }

    private fun handleRequest(request: BridgeRequest) {
        when (request.action) {
            "SET_PERFORMANCE_MODE" -> {
                val requestedMode = request.payload.optString("mode", "HIGH_PERFORMANCE")
                
                val responseData = JSONObject().apply {
                    put("currentMode", requestedMode)
                    put("cpuUsage", "85%")
                    put("gpuFreq", "670 MHz")
                    put("temperature", 38.2)
                    put("shizukuStatus", "READY")
                    put("memoryStatus", "OPTIMIZED")
                }
                
                val response = BridgeResponse(
                    requestId = request.requestId,
                    action = request.action,
                    success = true,
                    message = "Đã chuyển sang chế độ: $requestedMode",
                    data = responseData
                )
                sendResponseToWeb(response)
            }

            "GET_SYSTEM_STATUS" -> {
                val statusData = JSONObject().apply {
                    put("mode", "BALANCED")
                    put("shizukuStatus", "READY")
                    put("memoryStatus", "OPTIMIZED")
                    put("temperature", 36.5)
                    put("batteryLevel", 88)
                }

                val response = BridgeResponse(
                    requestId = request.requestId,
                    action = request.action,
                    success = true,
                    message = "Trạng thái hệ thống đã cập nhật",
                    data = statusData
                )
                sendResponseToWeb(response)
            }

            else -> {
                val response = BridgeResponse(
                    requestId = request.requestId,
                    action = request.action,
                    success = false,
                    message = "Hành động không xác định: ${request.action}"
                )
                sendResponseToWeb(response)
            }
        }
    }

    fun sendResponseToWeb(response: BridgeResponse) {
        mainHandler.post {
            val jsonStr = response.toJsonString()
            val escapedJson = jsonStr.replace("\\", "\\\\").replace("'", "\\'")
            val jsCode = "if (window.onNativeResponse) { window.onNativeResponse('$escapedJson'); }"
            webViewRef.get()?.evaluateJavascript(jsCode, null)
        }
    }
}
