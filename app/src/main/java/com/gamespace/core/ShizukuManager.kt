package com.gamespace.core

import android.content.pm.PackageManager
import rikka.shizuku.Shizuku
import java.util.concurrent.CopyOnWriteArrayList

/**
 * Quản lý vòng đời kết nối Binder và kiểm tra/xin quyền Shizuku an toàn chống crash.
 */
object ShizukuManager {
    const val SHIZUKU_REQ_CODE = 1001

    interface StateListener {
        fun OnShizukuStateChanged(isAvailable: Boolean, hasPermission: Boolean)
    }

    private val listeners = CopyOnWriteArrayList<StateListener>()

    private val binderReceivedListener = Shizuku.OnBinderReceivedListener {
        notifyListeners()
    }

    private val binderDeadListener = Shizuku.OnBinderDeadListener {
        notifyListeners()
    }

    private val permissionResultListener = Shizuku.OnRequestPermissionResultListener { requestCode, _ ->
        if (requestCode == SHIZUKU_REQ_CODE) {
            notifyListeners()
        }
    }

    fun init() {
        try {
            Shizuku.addBinderReceivedListenerSticky(binderReceivedListener)
            Shizuku.addBinderDeadListener(binderDeadListener)
            Shizuku.addRequestPermissionResultListener(permissionResultListener)
        } catch (t: Throwable) {
            t.printStackTrace()
        }
    }

    fun destroy() {
        try {
            Shizuku.removeBinderReceivedListener(binderReceivedListener)
            Shizuku.removeBinderDeadListener(binderDeadListener)
            Shizuku.removeRequestPermissionResultListener(permissionResultListener)
        } catch (t: Throwable) {
            t.printStackTrace()
        }
    }

    fun addListener(listener: StateListener) {
        try {
            if (!listeners.contains(listener)) {
                listeners.add(listener)
            }
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
            if (Shizuku.isPreV11()) {
                false
            } else {
                Shizuku.checkSelfPermission() == PackageManager.PERMISSION_GRANTED
            }
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
