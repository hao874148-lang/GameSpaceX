package com.gamespace.bridge

/**
 * Khai báo tên các Event giữa JavaScript và Kotlin Bridge.
 */
enum class BridgeEvents(val eventName: String) {
    INIT_STATE("INIT_STATE"),
    SET_PERFORMANCE_MODE("SET_PERFORMANCE_MODE"),
    REQUEST_SHIZUKU_PERMISSION("REQUEST_SHIZUKU_PERMISSION"),
    GET_SYSTEM_STATS("GET_SYSTEM_STATS"),
    CLEAN_MEMORY("CLEAN_MEMORY")
}
