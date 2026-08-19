package com.gamespace.bridge

import org.json.JSONObject

/**
 * Cấu trúc dữ liệu yêu cầu từ JavaScript gửi sang Native
 */
data class BridgeRequest(
    val requestId: String,
    val action: String,
    val payload: JSONObject
) {
    companion object {
        fun parse(jsonStr: String): BridgeRequest {
            val json = JSONObject(jsonStr)
            return BridgeRequest(
                requestId = json.optString("requestId", System.currentTimeMillis().toString()),
                action = json.optString("action", "UNKNOWN"),
                payload = json.optJSONObject("payload") ?: JSONObject()
            )
        }
    }
}

/**
 * Cấu trúc dữ liệu phản hồi từ Native trả về lại JavaScript
 */
data class BridgeResponse(
    val requestId: String,
    val action: String,
    val success: Boolean,
    val message: String,
    val data: JSONObject = JSONObject()
) {
    fun toJsonString(): String {
        val json = JSONObject()
        json.put("requestId", requestId)
        json.put("action", action)
        json.put("success", success)
        json.put("message", message)
        json.put("data", data)
        return json.toString()
    }
}
