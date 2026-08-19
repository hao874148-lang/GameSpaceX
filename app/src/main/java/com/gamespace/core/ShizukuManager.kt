package com.gamespace.core

import android.content.pm.PackageManager
import rikka.shizuku.Shizuku

object ShizukuManager {

    interface StateListener {
        fun onShizukuStateChanged(isAvailable: Boolean, hasPermission: Boolean)
    }

    private val listeners = mutableListOf<StateListener>()
    
    private val binderReceivedListener = Shizuku.OnBinderReceivedListener {
        notifyListeners()
    }
    
    private val requestPermissionResultListener = Shizuku.OnRequestPermissionResultListener { _, _ ->
        notifyListeners()
    }

    fun init() {
        Shizuku.addBinderReceivedListenerSticky(binderReceivedListener)
        Shizuku.addRequestPermissionResultListener(requestPermissionResultListener)
    }

    fun isShizukuAvailable(): Boolean {
        return try {
            Shizuku.pingBinder()
        } catch (e: Throwable) {
            false
        }
    }

    fun hasShizukuPermission(): Boolean {
        return if (isShizukuAvailable()) {
            try {
                Shizuku.checkSelfPermission() == PackageManager.PERMISSION_GRANTED
            } catch (e: Throwable) {
                false
            }
        } else {
            false
        }
    }

    fun addListener(listener: StateListener) {
        listeners.add(listener)
    }

    fun removeListener(listener: StateListener) {
        listeners.remove(listener)
    }

    private fun notifyListeners() {
        val available = isShizukuAvailable()
        val permitted = hasShizukuPermission()
        listeners.forEach { it.onShizukuStateChanged(available, permitted) }
    }

    fun destroy() {
        Shizuku.removeBinderReceivedListener(binderReceivedListener)
        Shizuku.removeRequestPermissionResultListener(requestPermissionResultListener)
    }
}
